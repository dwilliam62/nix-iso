#!/usr/bin/env bash
# Interactive installer for a mirrored Btrfs bootable NixOS system.
# - Prompts for timezone, keymap, hostname, username
# - Verifies at least two available, completely unmounted disks
# - Lets user select two target disks (sizes may differ; usable capacity ~ smaller disk)
# - Partitions both disks (GPT: 1GiB ESP + rest Btrfs)
# - Creates a Btrfs filesystem in RAID1 (data+metadata) across both disks
# - Creates subvolumes (@, @home, @nix, @snapshots)
# - Mounts with compress=zstd,discard=async,noatime and mounts both ESPs at /mnt/boot and /mnt/boot2
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
for dep in lsblk parted mkfs.fat mkfs.btrfs btrfs mount umount sed awk tee nixos-generate-config nixos-install blkid blockdev wipefs; do
  require "$dep"
done

# Defaults
TIMEZONE=${TIMEZONE:-America/New_York}
KEYMAP=${KEYMAP:-us}
HOSTNAME=${HOSTNAME:-nixos}
USERNAME=${USERNAME:-dwilliams}

echo "=== NixOS Btrfs Mirrored Boot Installer ==="
echo

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
avail_models=()
for name in "${ALL_DISKS[@]}"; do
  # Skip if any mountpoints exist under this disk
  if lsblk -n -o MOUNTPOINTS "/dev/$name" | grep -q "[^[:space:]]"; then
    continue
  fi
  model=$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | sed 's/^$/-/' )
  avail_names+=("$name")
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
  sel=$(echo "$sel" | tr ',' ' ')
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

# Sizes (for notice only)
HUM1=$(lsblk -dn -o SIZE "$DISK1")
HUM2=$(lsblk -dn -o SIZE "$DISK2")
if [ "$(blockdev --getsize64 "$DISK1")" -ne "$(blockdev --getsize64 "$DISK2")" ]; then
  echo
  echo "NOTICE: Selected disks are different sizes ($DISK1: $HUM1, $DISK2: $HUM2)."
  echo "Btrfs RAID1 usable capacity is approximately the size of the smaller device."
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
  parted -s "$d" mkpart primary btrfs 1025MiB 100%
}

echo "\nPartitioning $DISK1 and $DISK2 ..."
partition_disk "$DISK1"
partition_disk "$DISK2"

read P1A P2A < <(part_names "$DISK1")
read P1B P2B < <(part_names "$DISK2")

# Filesystems
echo "\nCreating filesystems ..."
mkfs.fat -F32 -n EFI_A "$P1A"
mkfs.fat -F32 -n EFI_B "$P1B"

# Create Btrfs RAID1 filesystem across both data partitions
mkfs.btrfs -f -L nixos -m raid1 -d raid1 "$P2A" "$P2B"

# Get the filesystem UUID (same across both devices)
FSUUID=$(blkid -s UUID -o value "$P2A")

# Subvolumes
echo "\nCreating subvolumes ..."
mkdir -p /mnt
mount -o subvolid=5 "/dev/disk/by-uuid/$FSUUID" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount target (include /.snapshots)
echo "\nMounting target ..."
mount -o compress=zstd,discard=async,noatime,subvol=@ "/dev/disk/by-uuid/$FSUUID" /mnt
mkdir -p /mnt/{home,nix,boot,boot2,.snapshots}
mount -o compress=zstd,discard=async,noatime,subvol=@home "/dev/disk/by-uuid/$FSUUID" /mnt/home
mount -o compress=zstd,discard=async,noatime,subvol=@nix "/dev/disk/by-uuid/$FSUUID" /mnt/nix
mount -o compress=zstd,discard=async,noatime,subvol=@snapshots "/dev/disk/by-uuid/$FSUUID" /mnt/.snapshots
mount "$P1A" /mnt/boot
mount "$P1B" /mnt/boot2

# Generate hardware config (will include all mounted subvolumes and ESPs)
nixos-generate-config --root /mnt

# Gather UUIDs for ESPs (for mirroredBoots devices)
UUID_B=$(blkid -s UUID -o value "$P1B")

# Write configuration.nix
CFG=/mnt/etc/nixos/configuration.nix
cat > "$CFG" <<NIXCONF
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot = {
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
    git ncftp htop btop pciutils btrfs-progs wget curl
    neovim gnused gawk ripgrep gnugrep findutils coreutils
  ];

  programs.mtr.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;

  services.openssh.enable = true;

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

