#!/usr/bin/env bash
# Interactive installer for a Btrfs-based NixOS system.
# - Prompts for timezone, keymap, hostname, username
# - Lets user select target disk
# - Partitions (GPT: 1GiB ESP + rest Btrfs), creates subvolumes (@, @home, @nix)
# - Mounts with compress=zstd,discard=async,noatime
# - Generates hardware config and writes a configuration.nix template
# - Runs nixos-install (root password will be prompted interactively)

set -euo pipefail

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mkfs.btrfs btrfs mount umount sed awk tee nixos-generate-config nixos-install; do
  require "$dep"
done

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

# Disk selection
echo
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL,TYPE | awk 'NR==1 || $4=="disk" {print}'
echo
read -r -p "Enter target disk (e.g., /dev/sda or /dev/nvme0n1): " DISK
[ -b "$DISK" ] || { echo "Not a block device: $DISK" >&2; exit 1; }

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
parted -s "$DISK" mkpart primary btrfs 1025MiB 100%

# Derive partition names
P1="$DISK"1
P2="$DISK"2
# NVMe naming: /dev/nvme0n1p1
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
  P1="${DISK}p1"; P2="${DISK}p2"
fi

# Filesystems
echo "\nCreating filesystems ..."
mkfs.fat -F32 -n EFI "$P1"
mkfs.btrfs -f -L nixos "$P2"

# Subvolumes
echo "\nCreating subvolumes ..."
mkdir -p /mnt
mount -o subvolid=5 "$P2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount target (include /.snapshots to aid tools like snapper)
echo "\nMounting target ..."
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

  system.stateVersion = "25.05";
}
NIXCONF

echo "\nConfiguration written to $CFG"

echo "\nStarting installation (you will be prompted to set the root password) ..."
nixos-install

echo "\nInstallation complete. You can reboot into the installed system."
