#!/usr/bin/env bash
# Interactive installer for a mirrored ZFS bootable NixOS system.
# - Prompts for timezone, keymap, hostname, username, pool name
# - Verifies at least two available, completely unmounted disks
# - Lets user select two target disks (sizes must be equal or one larger)
# - Partitions both disks (GPT: 1GiB ESP + rest for zpool)
# - Creates a mirrored zpool and datasets with zstd compression
# - Mounts datasets with legacy mountpoints; mounts both ESPs at /mnt/boot and /mnt/boot2
# - Generates hardware config and writes a configuration.nix including mirrored systemd-boot
# - Runs nixos-install (root password will be prompted interactively)

set -euo pipefail

# Require root; if not root, try to re-exec via sudo preserving env
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  else
    echo "This installer must be run as root. Try: sudo $0" >&2
    exit 1
  fi
fi

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat zpool zfs mount umount sed awk tee nixos-generate-config nixos-install blkid blockdev wipefs; do
  require "$dep"
done

# Guardrail: verify ZFS kernel module availability
check_zfs_kernel() {
  if lsmod 2>/dev/null | awk '{print $1}' | grep -qx zfs; then
    return 0
  fi
  if command -v modprobe >/dev/null 2>&1 && modprobe -q zfs 2>/dev/null; then
    return 0
  fi
  echo "ERROR: ZFS kernel module not available (lsmod/modprobe failed)." >&2
  echo "Install a kernel with ZFS support or load the module before proceeding." >&2
  exit 1
}

# Defaults
TIMEZONE=${TIMEZONE:-America/New_York}
KEYMAP=${KEYMAP:-us}
HOSTNAME=${HOSTNAME:-nixos}
USERNAME=${USERNAME:-dwilliams}
POOL=${POOL:-rpool}

# Generate a hostid for ZFS import in initrd
HOSTID=$(head -c4 /dev/urandom | od -A none -t x4 | awk '{print $1}')

echo "=== NixOS ZFS Mirrored Boot Installer ==="

# Environment diagnostics and guardrails
check_zfs_kernel
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container --quiet; then
  echo "WARNING: Running inside a container. Block device access, module loading, or efivars may not work." >&2
fi
if [ ! -d /sys/firmware/efi/efivars ]; then
  echo "NOTE: UEFI efivars not available; NVRAM enrollment may be skipped by systemd-boot." >&2
fi
# Refuse if any ZFS filesystems are mounted or pools imported
# Use /proc/self/mounts for an exact fstype match and show what we found.
if awk '$3=="zfs"{found=1; exit} END{exit !found}' /proc/self/mounts; then
  echo "ERROR: One or more ZFS filesystems are currently mounted:" >&2
  awk '$3=="zfs"{printf "  - %s on %s\n", $1, $2}' /proc/self/mounts >&2 || true
  echo "Please unmount them before running this installer." >&2
  exit 1
fi
# Consider pools imported only if zpool list actually produces rows.
if command -v zpool >/dev/null 2>&1; then
  if zpool list -H 2>/dev/null | grep -q .; then
    echo "ERROR: One or more ZFS pools are currently imported:" >&2
    zpool list -H 2>/dev/null >&2 || true
    echo "Export them before proceeding (zpool export <pool>)." >&2
    exit 1
  fi
fi

echo
echo "WARNING: ZFS on NixOS may be marked as BROKEN at times when the kernel and ZFS ABI drift."
echo "- Ensure you use a matching kernel+ZFS pair (e.g., linuxPackages_cachyos + zfs_cachyos), or pin nixpkgs to a known-good revision."
echo "- Avoid globally enabling nixpkgs.config.allowBroken unless you understand the risks (unbuilt/unsupported code, potential failures)."
echo "You have been warned."

# Prompt helpers
read_default() {
  local prompt="$1" default="$2" var
  read -r -p "$prompt [$default]: " var || true
  if [ -z "${var}" ]; then echo "$default"; else echo "$var"; fi
}

# Collect inputs
TIMEZONE=$(read_default "Timezone (e.g., America/New_York)" "$TIMEZONE")
KEYMAP=$(read_default "Console keymap (e.g., us, uk, de, fr)" "$KEYMAP")
HOSTNAME=$(read_default "Hostname" "$HOSTNAME")
USERNAME=$(read_default "Username" "$USERNAME")
POOL=$(read_default "ZFS pool name" "$POOL")

# Prompt for user password (used for the installed system account)
USER_HASH=""
if command -v openssl >/dev/null 2>&1; then
  while true; do
    read -rs -p "Password for user '$USERNAME': " USER_PW1; echo
    read -rs -p "Confirm password for '$USERNAME': " USER_PW2; echo
    if [ "$USER_PW1" != "$USER_PW2" ]; then
      echo "Passwords do not match. Please try again." >&2
      continue
    fi
    USER_HASH=$(printf %s "$USER_PW1" | openssl passwd -6 -stdin)
    unset USER_PW1 USER_PW2
    break
  done
else
  echo "Warning: openssl not found; user '$USERNAME' will be created without a password. You can set it after first boot." >&2
fi

# Prepare Nix line for initialHashedPassword with quotes preserved
HASH_LINE=""
if [ -n "${USER_HASH}" ]; then
  ESC_HASH=${USER_HASH//\"/\\\"}
  HASH_LINE="    initialHashedPassword = \"${ESC_HASH}\";"
fi

# Build list of available, completely unmounted disks
echo
echo "Scanning for available, unmounted disks ..."
mapfile -t ALL_DISKS < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}')
avail_names=()
avail_sizes=()
avail_models=()
for name in "${ALL_DISKS[@]}"; do
  # Skip if any mountpoints exist under this disk
  if lsblk -n -o MOUNTPOINTS "/dev/$name" | grep -q "[^[:space:]]"; then
    continue
  fi
  size_b=$(blockdev --getsize64 "/dev/$name" 2>/dev/null || echo 0)
  model=$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | sed 's/^$/-/' )
  avail_names+=("$name")
  avail_sizes+=("$size_b")
  avail_models+=("$model")
done

if [ "${#avail_names[@]}" -lt 2 ]; then
  echo "Need at least TWO completely unmounted disks. Found: ${#avail_names[@]}" >&2
  echo "Ensure target disks and their partitions are unmounted before proceeding." >&2
  exit 1
fi

echo
echo "Available disks:"  
idx=1
for i in "${!avail_names[@]}"; do
  name="${avail_names[$i]}"
  size_h=$(lsblk -dn -o SIZE "/dev/$name")
  model="${avail_models[$i]}"
  printf "[%d] /dev/%s  %s  %s\n" "$idx" "$name" "$size_h" "$model"
  idx=$((idx+1))
done

echo
read -r -p "Select TWO disks by numbers (e.g., '1 2') or enter two device paths (e.g., '/dev/sda /dev/sdb'): " selection

parse_selection() {
  local sel="$1"
  # Normalize commas -> spaces
  sel=$(echo "$sel" | tr ',' ' ')
  # Split into array
  read -r -a tokens <<<"$sel"
  if [ "${#tokens[@]}" -ne 2 ]; then
    echo "expect_two"; return 0
  fi
  local a="${tokens[0]}" b="${tokens[1]}"
  if [[ "$a" =~ ^/dev/ ]]; then
    DISK1="$a"; DISK2="$b"
  else
    if [[ ! "$a" =~ ^[0-9]+$ ]] || [[ ! "$b" =~ ^[0-9]+$ ]]; then
      echo "invalid"; return 0
    fi
    if [ "$a" -lt 1 ] || [ "$a" -gt "${#avail_names[@]}" ] || [ "$b" -lt 1 ] || [ "$b" -gt "${#avail_names[@]}" ]; then
      echo "out_of_range"; return 0
    fi
    DISK1="/dev/${avail_names[$((a-1))]}"
    DISK2="/dev/${avail_names[$((b-1))]}"
  fi
  echo "ok"
}

result=$(parse_selection "$selection")
if [ "$result" != "ok" ]; then
  case "$result" in
    expect_two) echo "Please provide exactly two selections." >&2 ;;
    invalid) echo "Invalid input. Use numbers or device paths." >&2 ;;
    out_of_range) echo "Selection out of range." >&2 ;;
    *) echo "Invalid selection." >&2 ;;
  esac
  exit 1
fi

if [ "$DISK1" = "$DISK2" ]; then
  echo "You selected the same disk twice. Please select two different disks." >&2
  exit 1
fi

# Validate block devices and write access
for d in "$DISK1" "$DISK2"; do
  [ -b "$d" ] || { echo "Not a block device: $d" >&2; exit 1; }
  ro=$(blockdev --getro "$d" || echo 1)
  if [ "$ro" != "0" ]; then
    echo "Device appears read-only: $d. Check settings/permissions." >&2
    exit 1
  fi
  # Re-check unmounted at selection time
  if lsblk -n -o MOUNTPOINTS "$d" | grep -q "[^[:space:]]"; then
    echo "Device $d or its partitions appear mounted. Unmount first." >&2
    exit 1
  fi
 done

# Check sizes
SIZE1=$(blockdev --getsize64 "$DISK1")
SIZE2=$(blockdev --getsize64 "$DISK2")
HUM1=$(lsblk -dn -o SIZE "$DISK1")
HUM2=$(lsblk -dn -o SIZE "$DISK2")

if [ "$SIZE1" -ne "$SIZE2" ]; then
  echo
  echo "NOTICE: Selected disks are different sizes ($DISK1: $HUM1, $DISK2: $HUM2)."
  echo "The ZFS mirror will use only the size of the smaller disk."
fi

# Final destructive confirmation
echo
echo "WARNING: This will destroy ALL data on $DISK1 AND $DISK2"
read -r -p "Type 'INSTALL' to proceed: " confirm
[ "$confirm" = "INSTALL" ] || { echo "Aborted"; exit 1; }

# Helper to get partition names
part_names() {
  local d="$1"
  local p1 p2
  if [[ "$d" == *nvme* ]] || [[ "$d" == *mmcblk* ]]; then
    p1="${d}p1"; p2="${d}p2"
  else
    p1="${d}1"; p2="${d}2"
  fi
  echo "$p1 $p2"
}

# Partition both disks
partition_disk() {
  local d="$1"
  wipefs -af "$d"
  parted -s "$d" mklabel gpt
  parted -s "$d" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$d" set 1 esp on
  parted -s "$d" mkpart primary 1025MiB 100%
}

echo "\nPartitioning $DISK1 and $DISK2 ..."
partition_disk "$DISK1"
partition_disk "$DISK2"

read P1A P2A < <(part_names "$DISK1")
read P1B P2B < <(part_names "$DISK2")

# Filesystems (EFI) and ZFS pool
echo "\nCreating filesystems and ZFS pool ..."
mkfs.fat -F32 -n EFI_A "$P1A"
mkfs.fat -F32 -n EFI_B "$P1B"

# Create mirrored zpool with safe defaults + compression
zpool create -f \
  -o ashift=12 \
  -o autotrim=on \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  -R /mnt \
  "$POOL" mirror "$P2A" "$P2B"

# Datasets (legacy mountpoints for control via /etc/fstab)
# Container for root; actual root lives under root/nixos
zfs create -o mountpoint=none "$POOL/root"
zfs create -o mountpoint=legacy "$POOL/root/nixos"

# Core datasets
zfs create -o mountpoint=legacy "$POOL/home"
zfs create -o mountpoint=legacy -o atime=off "$POOL/nix"

# Split var to tune properties and snapshot policy
zfs create -o mountpoint=none "$POOL/var"
zfs create -o mountpoint=legacy -o exec=off -o devices=off "$POOL/var/log"
zfs create -o mountpoint=legacy -o exec=off -o devices=off -o com.sun:auto-snapshot=false "$POOL/var/cache"
zfs create -o mountpoint=legacy -o exec=off -o devices=off -o com.sun:auto-snapshot=false "$POOL/var/tmp"
zfs create -o mountpoint=legacy "$POOL/var/lib"

# Mount target
echo "\nMounting target ..."
mkdir -p /mnt
mount -t zfs "$POOL/root/nixos" /mnt
mkdir -p /mnt/{home,nix,boot,boot2,var,var/log,var/cache,var/tmp,var/lib}
mount -t zfs "$POOL/home" /mnt/home
mount -t zfs "$POOL/nix" /mnt/nix
mount -t zfs "$POOL/var/log" /mnt/var/log
mount -t zfs "$POOL/var/cache" /mnt/var/cache
mount -t zfs "$POOL/var/tmp" /mnt/var/tmp
mount -t zfs "$POOL/var/lib" /mnt/var/lib
mount "$P1A" /mnt/boot
mount "$P1B" /mnt/boot2

# Generate hardware config
nixos-generate-config --root /mnt

# Gather UUIDs for ESPs (for mirroredBoots devices)
UUID_A=$(blkid -s UUID -o value "$P1A")
UUID_B=$(blkid -s UUID -o value "$P1B")

# Write configuration.nix
CFG=/mnt/etc/nixos/configuration.nix
cat > "$CFG" <<NIXCONF
{ pkgs, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot = {
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems = [ "zfs" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # Replicate systemd-boot to second ESP mounted at /boot2
      systemd-boot.mirroredBoots = [
        {
          path = "/boot2";
          devices = [ "/dev/disk/by-uuid/${UUID_B}" ];
        }
      ];
    };
    kernelModules = [ "z3fold" ];
    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=20"
      "zswap.zpool=z3fold"
    ];
  };

  # Required for ZFS root import in initrd
  networking.hostId = "${HOSTID}";

  # Optional ZFS services
  services.zfs.autoScrub.enable = true;

  networking = {
    hostName = "${HOSTNAME}";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  time.timeZone = "${TIMEZONE}";
  console.keyMap = "${KEYMAP}";

  users.users.${USERNAME} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" ];
${HASH_LINE:+${HASH_LINE}}
  };

  environment.systemPackages = with pkgs; [
    git ncftp htop btop pciutils wget curl
    neovim gnused gawk ripgrep gnugrep findutils coreutils
  ];

  programs.mtr.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;

  services.openssh.enable = true;
  services.fstrim.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  system.stateVersion = "25.11";
}
NIXCONF

echo "\nConfiguration written to $CFG"

echo "\nStarting installation (you will be prompted to set the root password) ..."
nixos-install

echo "\nInstallation complete. You can reboot into the installed system."

