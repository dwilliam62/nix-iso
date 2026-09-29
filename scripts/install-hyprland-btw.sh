#!/usr/bin/env bash
# Author: Don Williams
# hyprland-btw installer: prepare disk, mount filesystems, and install hyprland-btw
# - Prompts for filesystem, disk, hostname, username, GPU profile, timezone, keyboard
# - Partitions and formats disk modeled after install-ddubsos.sh
# - Mounts target and generates hardware-configuration.nix
# - Clones hyprland-btw repo into /mnt/home/username/hyprland-btw
# - Updates flake.nix, configuration.nix, home.nix with user settings
# - Runs nixos-install with the hyprland-btw flake

set -euo pipefail

# Re-exec as root if needed
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  else
    echo "This installer must be run as root. Try: sudo $0" >&2
    exit 1
  fi
fi

# Ensure sbin paths available (parted, mkfs.*)
for p in /usr/sbin /sbin /usr/local/sbin /run/current-system/sw/bin; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) :;; *) PATH="$p:$PATH";; esac
done
export PATH

# Dependencies
req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mount umount sed awk grep git nixos-generate-config nixos-install; do
  req "$dep"
done

# Paths
LIVE_HWCFG="/mnt/etc/nixos/hardware-configuration.nix"
HYPRLAND_REMOTE="https://github.com/dwilliam62/hyprland-btw.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║ ${1}${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_error() {
  echo -e "${RED}Error: ${1}${NC}"
}

read_default() {
  local prompt="$1" default="$2" var
  read -r -p "$prompt [$default]: " var || true
  if [ -z "${var}" ]; then echo "$default"; else echo "$var"; fi
}

any_mounts_under() {
  local d="$1"
  lsblk -rno MOUNTPOINTS "$d" 2>/dev/null | awk '($0!="" && $0!="-") {found=1; exit} END{exit !found}'
}

select_disk() {
  echo >&2
  echo "Available disks:" >&2
  mapfile -t DISK_ROWS < <(lsblk -dn -o NAME,SIZE,TYPE,MODEL | awk '$3=="disk" {m=$4; if (m=="") m="-"; printf "%s\t%s\t%s\n", $1,$2,m}')
  if [ "${#DISK_ROWS[@]}" -eq 0 ]; then
    echo "No disks detected." >&2
    exit 1
  fi
  local idx=1
  for row in "${DISK_ROWS[@]}"; do
    local name size model
    name=$(echo "$row" | awk '{print $1}')
    size=$(echo "$row" | awk '{print $2}')
    model=$(echo "$row" | awk '{print $3}')
    printf "[%d] /dev/%s  %s  %s\n" "$idx" "$name" "$size" "$model" >&2
    idx=$((idx+1))
  done
  echo >&2
  printf "Select disk by number (1-%d): " "${#DISK_ROWS[@]}" >&2
  local choice
  if [ -t 0 ]; then
    read -r choice
  else
    read -r choice </dev/tty
  fi
  local disk
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DISK_ROWS[@]}" ]; then
    local sel_row sel_name
    sel_row="${DISK_ROWS[$((choice-1))]}"
    sel_name=$(echo "$sel_row" | awk '{print $1}')
    disk="/dev/$sel_name"
  else
    echo "Invalid selection: $choice" >&2
    exit 1
  fi
  [ -b "$disk" ] || { echo "Not a block device: $disk" >&2; exit 1; }
  echo "$disk"
}

part_names_for_disk() {
  local d="$1"; local p1 p2
  if [[ "$d" == *nvme* ]] || [[ "$d" == *mmcblk* ]]; then p1="${d}p1"; p2="${d}p2"; else p1="${d}1"; p2="${d}2"; fi
  echo "$p1 $p2"
}

prep_btrfs() {
  local disk="$1"
  printf '\nPartitioning %s ...\n' "$disk"
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart primary btrfs 1025MiB 100%
  command -v partprobe >/dev/null 2>&1 && partprobe "$disk" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  printf '\nCreating filesystems ...\n'
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.btrfs -f -L nixos "$P2"
  printf '\nCreating subvolumes ...\n'
  mkdir -p /mnt
  mount -o subvolid=5 "$P2" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@nix
  btrfs subvolume create /mnt/@snapshots
  umount /mnt
  printf '\nMounting target ...\n'
  mount -o compress=zstd,discard=async,noatime,subvol=@ "$P2" /mnt
  mkdir -p /mnt/{home,nix,boot,.snapshots}
  mount -o compress=zstd,discard=async,noatime,subvol=@home "$P2" /mnt/home
  mount -o compress=zstd,discard=async,noatime,subvol=@nix "$P2" /mnt/nix
  mount -o compress=zstd,discard=async,noatime,subvol=@snapshots "$P2" /mnt/.snapshots
  mount "$P1" /mnt/boot
}

prep_ext4() {
  local disk="$1"
  printf '\nPartitioning %s ...\n' "$disk"
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart primary ext4 1025MiB 100%
  command -v partprobe >/dev/null 2>&1 && partprobe "$disk" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  printf '\nCreating filesystems ...\n'
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.ext4 -F -L nixos "$P2"
  printf '\nMounting target ...\n'
  mkdir -p /mnt
  mount -o noatime "$P2" /mnt
  mkdir -p /mnt/{home,nix,boot,.snapshots}
  mount "$P1" /mnt/boot
}

prep_xfs() {
  local disk="$1"
  printf '\nPartitioning %s ...\n' "$disk"
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart primary xfs 1025MiB 100%
  command -v partprobe >/dev/null 2>&1 && partprobe "$disk" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  printf '\nCreating filesystems ...\n'
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.xfs -f -L nixos "$P2"
  printf '\nMounting target ...\n'
  mkdir -p /mnt
  mount -o noatime "$P2" /mnt
  mkdir -p /mnt/{home,nix,boot,.snapshots}
  mount "$P1" /mnt/boot
}

# Main flow
print_header "hyprland-btw Installer"

HOSTNAME=$(read_default "Hostname" "hyprland-btw")
if [ "$HOSTNAME" = "default" ] || ! [[ "$HOSTNAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid hostname '$HOSTNAME': choose a name other than 'default' using letters, digits, '.', '_' or '-'" >&2
  exit 1
fi
USERNAME=$(read_default "Username" "nixos")
TIMEZONE=$(read_default "Timezone" "America/New_York")
KEYBOARD=$(read_default "Keyboard layout" "us")
GPU_PROFILE=$(read_default "GPU profile (amd/intel/nvidia/vm)" "vm")

# Filesystem selection
echo
echo "Select filesystem:"
echo "  1) Btrfs (recommended)"
echo "  2) ext4"
echo "  3) XFS"
read -r -p "Choice [1-3]: " FS_CHOICE
case "${FS_CHOICE:-1}" in
  1) FS="btrfs" ;;
  2) FS="ext4" ;;
  3) FS="xfs" ;;
  *) echo "Invalid choice" >&2; exit 1 ;;
esac

# Disk selection
DISK=$(select_disk)
echo
echo -e "${RED}WARNING: This will destroy ALL data on $DISK${NC}"
read -r -p "Type 'INSTALL' to proceed: " ok
[ "$ok" = "INSTALL" ] || { echo "Aborted"; exit 1; }

# Unmount check
if any_mounts_under "$DISK"; then
  echo "Device appears mounted. Unmount first." >&2
  exit 1
fi

# Prepare filesystems
case "$FS" in
  btrfs) prep_btrfs "$DISK" ;;
  ext4)  prep_ext4  "$DISK" ;;
  xfs)   prep_xfs   "$DISK" ;;
  *) echo "Unsupported FS: $FS" >&2; exit 1 ;;
esac

# Generate hardware config
print_header "Generating Hardware Configuration"
nixos-generate-config --root /mnt

# Clone hyprland-btw
print_header "Cloning hyprland-btw"
mkdir -p /mnt/home/"$USERNAME"
HYPRLAND_TARGET="/mnt/home/$USERNAME/hyprland-btw"
rm -rf "$HYPRLAND_TARGET"
git clone --depth 1 "$HYPRLAND_REMOTE" "$HYPRLAND_TARGET"
cd "$HYPRLAND_TARGET"

# Update configurations using awk (safer than sed)
print_header "Configuring hyprland-btw"

# Update configuration.nix
cp ./configuration.nix ./configuration.nix.bak
awk -v tz="$TIMEZONE" '/^  time\.timeZone = / { sub(/= "[^"]*"/, "= \"" tz "\""); } { print }' ./configuration.nix.bak > ./configuration.nix
awk -v ckm="$KEYBOARD" -v kbl="$KEYBOARD" '
  /^  console\.keyMap = / { sub(/= "[^"]*"/, "= \"" ckm "\""); }
  /^    xserver\.xkb\.layout = / { sub(/= "[^"]*"/, "= \"" kbl "\""); }
  { print }
' ./configuration.nix > ./configuration.nix.tmp && mv ./configuration.nix.tmp ./configuration.nix

# Replace default dwilliams user with the selected username
echo -e "${GREEN}Setting up user entry for $USERNAME...${NC}"
awk -v newuser="$USERNAME" '
  /^  users\.users\."dwilliams" = \{/ { gsub(/dwilliams/, newuser); }
  { print }
' ./configuration.nix > ./configuration.nix.tmp && mv ./configuration.nix.tmp ./configuration.nix

# Note: The hideUsers setting is added to ly settings above

# Note: ly display manager configuration is in hyprland-btw/configuration.nix
# If you want to switch from ly to greetd with tuigreet for better user filtering,
# see the commented-out ly configuration and greetd setup in configuration.nix

# Point the flake's Home Manager user at the chosen username. The flake names
# the HM user from mkHost's `userName ? "dwilliams"` default (used for both
# users.${userName} and specialArgs), so update that default.
awk -v un="$USERNAME" '
  /userName \? "dwilliams"/ { sub(/userName \? "dwilliams"/, "userName ? \"" un "\""); }
  { print }
' ./flake.nix > ./flake.nix.tmp && mv ./flake.nix.tmp ./flake.nix

# Create/refresh the host directory. The flake auto-discovers every directory
# under ./hosts and exposes nixosConfigurations.<dirname> for it, so this is
# what makes `.#$HOSTNAME` exist. (The old `nixosConfigurations.hyprland-btw =`
# rename no longer applies - hosts are discovered, not listed in flake.nix.)
case "$GPU_PROFILE" in
  amd)    DRV_AMD=true;  DRV_INTEL=false; DRV_NVIDIA=false; VM_GUEST=false ;;
  intel)  DRV_AMD=false; DRV_INTEL=true;  DRV_NVIDIA=false; VM_GUEST=false ;;
  nvidia) DRV_AMD=false; DRV_INTEL=false; DRV_NVIDIA=true;  VM_GUEST=false ;;
  vm|*)   DRV_AMD=false; DRV_INTEL=false; DRV_NVIDIA=false; VM_GUEST=true  ;;
esac
echo -e "${GREEN}Configuring host '$HOSTNAME' in ./hosts/$HOSTNAME...${NC}"
if [ "$HOSTNAME" != "default" ]; then
  rm -rf "./hosts/$HOSTNAME"
fi
cp -r ./hosts/default "./hosts/$HOSTNAME"
cat > "./hosts/$HOSTNAME/default.nix" <<HOSTEOF
{...}: {
  imports = [
    ./hardware.nix
  ];

  networking.hostName = "$HOSTNAME";

  drivers = {
    amdgpu.enable = $DRV_AMD;
    intel.enable = $DRV_INTEL;
    nvidia.enable = $DRV_NVIDIA;
  };

  vm.guest-services.enable = $VM_GUEST;
}
HOSTEOF

# Update home.nix
awk -v un="$USERNAME" '
  /username = lib\.mkDefault / { sub(/"[^"]*"/, "\"" un "\""); }
  /homeDirectory = lib\.mkDefault / { sub(/"[^"]*"/, "\"" "/home/" un "\""); }
  { print }
' ./home.nix > ./home.nix.tmp && mv ./home.nix.tmp ./home.nix

rm -f ./configuration.nix.bak

# Copy the machine's generated hardware config into the host directory.
# hosts/<host>/default.nix imports ./hardware.nix, and the current flake has no
# top-level hardware-configuration.nix, so the file must live under hosts/$HOSTNAME.
cp "$LIVE_HWCFG" "./hosts/$HOSTNAME/hardware.nix"

# Stage all changes. Nix builds a git flake from the *tracked* tree, so the new
# hosts/$HOSTNAME directory (and the edited files) must be added, otherwise the
# flake will not expose nixosConfigurations.$HOSTNAME.
git add -A

# Validate flake.lock: reject missing files, unresolved git merge-conflict
# markers, or (when a parser is available) invalid JSON. Upstream copies have
# shipped a flake.lock with committed conflict markers, which Nix cannot parse
# ("json.exception.parse_error.101 ... expected string literal").
have_valid_lock() {
  [ -f ./flake.lock ] || return 1
  if grep -qE '^(<<<<<<<|>>>>>>>|=======$)' ./flake.lock; then
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json; json.load(open("flake.lock"))' >/dev/null 2>&1 || return 1
  fi
  return 0
}

# Refresh flake.lock after modifications to avoid narHash mismatches.
# If it is missing or corrupt, drop it so Nix regenerates a clean lock.
print_header "Refreshing flake.lock"
if ! have_valid_lock; then
  echo -e "${YELLOW}flake.lock missing or invalid; regenerating from scratch${NC}"
  rm -f ./flake.lock
fi
HOME=/root nix flake update --option accept-flake-config true

# Re-stage in case flake.lock was regenerated (untracked files are invisible to
# a git flake).
git add -A

# Install
print_header "Starting NixOS Installation"
HOME=/root nixos-install --flake ".#$HOSTNAME" --option accept-flake-config true --no-write-lock-file

# Check if installation succeeded
if [ $? -eq 0 ]; then
  print_header "Post-Installation Setup"

  # Optionally remove git metadata from the installed config
  rm -rf ./.git ./.gitmodules 2>/dev/null || true
  
  # Fix ownership of hyprland-btw directory (using UID/GID from mounted system)
  echo -e "${BLUE}Fixing ownership of hyprland-btw...${NC}"
  # Get the UID and GID of the user from the mounted system
  USER_UID=$(awk -F: -v u="$USERNAME" '$1==u {print $3}' /mnt/etc/passwd)
  USER_GID=$(awk -F: -v u="$USERNAME" '$1==u {print $4}' /mnt/etc/passwd)
  if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then
    if chown -R "$USER_UID:$USER_GID" "/mnt/home/$USERNAME/hyprland-btw"; then
      echo -e "${GREEN}✓ Ownership fixed (UID:$USER_UID GID:$USER_GID)${NC}"
    else
      echo -e "${YELLOW}⚠ Could not update ownership for /home/$USERNAME/hyprland-btw${NC}"
      echo -e "${YELLOW}    After login, run:${NC} sudo chown -R $USERNAME:\$(id -gn $USERNAME) /home/$USERNAME/hyprland-btw"
    fi
  else
    echo -e "${YELLOW}⚠ Could not determine user UID/GID for ownership fix${NC}"
    echo -e "${YELLOW}    After login, run:${NC} sudo chown -R $USERNAME:\$(id -gn $USERNAME) /home/$USERNAME/hyprland-btw"
  fi
  echo
  
  print_header "Setting User Password"
  
  # Set user password
  echo -e "${YELLOW}Setting password for user '$USERNAME'...${NC}"
  while true; do
    read -rs -p "Password for user '$USERNAME': " USER_PW1; echo >&2
    read -rs -p "Confirm password for '$USERNAME': " USER_PW2; echo >&2
    if [ "$USER_PW1" = "$USER_PW2" ]; then
      USER_HASH=$(printf %s "$USER_PW1" | openssl passwd -6 -stdin)
      unset USER_PW1 USER_PW2
      break
    else
      echo -e "${RED}Passwords do not match. Please try again.${NC}" >&2
    fi
  done
  
  echo -e "${BLUE}Setting password for user '$USERNAME'...${NC}"
  # Directly modify shadow file on /mnt (not in chroot, to avoid missing tools)
  awk -v user="$USERNAME" -v hash="$USER_HASH" -F: '
    $1 == user { $2 = hash; print; next }
    { print }
  ' OFS=: /mnt/etc/shadow > /mnt/etc/shadow.tmp && mv /mnt/etc/shadow.tmp /mnt/etc/shadow
  chmod 000 /mnt/etc/shadow
  echo -e "${GREEN}✓ User password set${NC}"
  echo
  
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║ Installation complete! System is ready to reboot.${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
else
  echo -e "${RED}Installation failed!${NC}"
  exit 1
fi
