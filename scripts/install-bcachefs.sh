#!/usr/bin/env bash
# Interactive installer for a bcachefs-based NixOS system.
# - Prompts for timezone, keymap, hostname, username
# - Lets user select target disk
# - Partitions (GPT: 1GiB ESP + rest bcachefs)
# - Formats with zstd compression enabled
# - Mounts with noatime (use fstrim.timer for SSD TRIM)
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

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mkfs.bcachefs mount umount sed awk tee nixos-generate-config nixos-install; do
  require "$dep"
done

# Defaults
TIMEZONE=${TIMEZONE:-America/New_York}
KEYMAP=${KEYMAP:-us}
HOSTNAME=${HOSTNAME:-nixos}
USERNAME=${USERNAME:-dwilliams}

echo "=== NixOS bcachefs Installer ==="

# Prominent warning about bcachefs stability
echo
echo "WARNING: bcachefs is experimental and provided AS-IS."
echo "- It may change or be removed from kernels in the future."
echo "- Do NOT use bcachefs for production environments or to store important data."

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
mount | grep -E "^$DISK" && { echo "Device appears mounted. Unmount first." >&2; exit 1; } || true

# Partition
echo "\nPartitioning $DISK ..."
wipefs -af "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary bcachefs 1025MiB 100%

# Derive partition names
P1="$DISK"1
P2="$DISK"2
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
  P1="${DISK}p1"; P2="${DISK}p2"
fi

# Filesystems
echo "\nCreating filesystems ..."
mkfs.fat -F32 -n EFI "$P1"
mkfs.bcachefs -f --compression=zstd -L nixos "$P2"

# Mount target
echo "\nMounting target ..."
mkdir -p /mnt
mount -o noatime "$P2" /mnt
mkdir -p /mnt/{home,nix,boot,.snapshots}
mount "$P1" /mnt/boot

# Generate hardware config
nixos-generate-config --root /mnt

# Write configuration.nix
CFG=/mnt/etc/nixos/configuration.nix
cat > "$CFG" <<NIXCONF
{ pkgs, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot = {
    supportedFilesystems = [ "bcachefs" ];
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
    git ncftp htop btop pciutils bcachefs-tools wget curl
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

