#!/usr/bin/env bash
# Interactive installer for a Btrfs-based NixOS system.
# - Prompts for timezone, keymap, hostname, username
# - Lets user select target disk
# - Partitions (GPT: 1GiB ESP + rest Btrfs), creates subvolumes (@, @home, @nix)
# - Mounts with compress=zstd,discard=async,noatime
# - Generates hardware config and writes a configuration.nix template
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

# Ensure common sbin locations are in PATH (parted, mkfs, lsblk may live in sbin)
if ! printf %s "$PATH" | grep -q "/usr/sbin"; then PATH="/usr/sbin:$PATH"; fi
if ! printf %s "$PATH" | grep -q "/sbin"; then PATH="/sbin:$PATH"; fi
if [ -d /usr/local/sbin ] && ! printf %s "$PATH" | grep -q "/usr/local/sbin"; then PATH="/usr/local/sbin:$PATH"; fi
if [ -d /run/current-system/sw/bin ] && ! printf %s "$PATH" | grep -q "/run/current-system/sw/bin"; then PATH="/run/current-system/sw/bin:$PATH"; fi
export PATH

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mkfs.btrfs btrfs mount umount sed awk tee nixos-generate-config nixos-install wipefs; do
  require "$dep"
done

# Environment diagnostics and guardrails
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container --quiet; then
  echo "WARNING: Running inside a container. Block device access or efivars may not work." >&2
fi
if [ ! -d /sys/firmware/efi/efivars ]; then
  echo "NOTE: UEFI efivars not available; NVRAM enrollment may be skipped by systemd-boot." >&2
fi
# Refuse if any btrfs filesystems are mounted; show what was detected
if awk '$3=="btrfs"{found=1; exit} END{exit !found}' /proc/self/mounts; then
  echo "ERROR: One or more btrfs filesystems are currently mounted:" >&2
  awk '$3=="btrfs"{printf "  - %s on %s\n", $1, $2}' /proc/self/mounts >&2 || true
  echo "Please unmount them before running this installer." >&2
  exit 1
fi

# Defaults
TIMEZONE=${TIMEZONE:-America/New_York}
KEYMAP=${KEYMAP:-us}
HOSTNAME=${HOSTNAME:-nixos}
USERNAME=${USERNAME:-dwilliams}

echo "=== NixOS Btrfs Installer ==="
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

# Disk selection
echo
echo "Available disks:"
# Build a numbered list for safer selection (handles virtio: vda)
mapfile -t DISK_ROWS < <(lsblk -dn -o NAME,SIZE,TYPE,MODEL | awk '$3=="disk" {m=$4; if (m=="") m="-"; printf "%s\t%s\t%s\n", $1,$2,m}')
if [ "${#DISK_ROWS[@]}" -eq 0 ]; then
  echo "No disks detected. Are you running in a VM without storage, or missing permissions?" >&2
  exit 1
fi
idx=1
for row in "${DISK_ROWS[@]}"; do
  name=$(echo "$row" | awk '{print $1}')
  size=$(echo "$row" | awk '{print $2}')
  model=$(echo "$row" | awk '{print $3}')
  printf "[%d] /dev/%s  %s  %s\n" "$idx" "$name" "$size" "$model"
  idx=$((idx+1))
done
echo
read -r -p "Select disk by number (1-${#DISK_ROWS[@]}) or enter device path (/dev/sdX, /dev/vdX, /dev/nvmeXnY): " choice
if [[ "$choice" =~ ^/dev/ ]]; then
  DISK="$choice"
elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DISK_ROWS[@]}" ]; then
  sel_row="${DISK_ROWS[$((choice-1))]}"
  sel_name=$(echo "$sel_row" | awk '{print $1}')
  DISK="/dev/$sel_name"
else
  echo "Invalid selection: $choice" >&2
  exit 1
fi

# Validate block device and write access (not read-only)
[ -b "$DISK" ] || { echo "Not a block device: $DISK" >&2; exit 1; }
if command -v blockdev >/dev/null 2>&1; then
  ro=$(blockdev --getro "$DISK" || echo 1)
  if [ "$ro" != "0" ]; then
    echo "Device appears read-only: $DISK (blockdev --getro != 0). Check VM settings and permissions." >&2
    exit 1
  fi
fi

# Final confirmation
echo
echo "WARNING: This will destroy ALL data on $DISK"
read -r -p "Type 'INSTALL' to proceed: " confirm
[ "$confirm" = "INSTALL" ] || { echo "Aborted"; exit 1; }

# Ensure not mounted
if mount | grep -Eq "^$DISK"; then
  echo "Device appears mounted. Unmount first." >&2
  exit 1
fi

# Partition
printf '\nPartitioning %s ...\n' "$DISK"
wipefs -af "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary btrfs 1025MiB 100%

# Derive partition names
P1="$DISK"1
P2="$DISK"2
# NVMe naming: /dev/nvme0n1p1
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
  P1="${DISK}p1"; P2="${DISK}p2"
fi

# Filesystems
printf '\nCreating filesystems ...\n'
mkfs.fat -F32 -n EFI "$P1"
mkfs.btrfs -f -L nixos "$P2"

# Subvolumes
printf '\nCreating subvolumes ...\n'
mkdir -p /mnt
mount -o subvolid=5 "$P2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount target (include /.snapshots to aid tools like snapper)
printf '\nMounting target ...\n'
mount -o compress=zstd,discard=async,noatime,subvol=@ "$P2" /mnt
mkdir -p /mnt/{home,nix,boot,.snapshots}
mount -o compress=zstd,discard=async,noatime,subvol=@home "$P2" /mnt/home
mount -o compress=zstd,discard=async,noatime,subvol=@nix "$P2" /mnt/nix
mount -o compress=zstd,discard=async,noatime,subvol=@snapshots "$P2" /mnt/.snapshots
mount "$P1" /mnt/boot

# Generate hardware config (will include all mounted subvolumes)
nixos-generate-config --root /mnt

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
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    accept-flake-config = true;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  system.stateVersion = "25.11";
}
NIXCONF

printf '\nConfiguration written to %s\n' "$CFG"

printf '\nStarting installation (you will be prompted to set the root password) ...\n'
nixos-install

printf '\nInstallation complete. You can reboot into the installed system.\n'
