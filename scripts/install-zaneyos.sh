#!/usr/bin/env bash

######################################
# Install script for ZaneyOS (for nix-iso)
# Author: Don Williams (aka ddubs)
# Date: 2025-12-23
# Adapted from ZaneyOS official installer
#######################################

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

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Define log file
LOG_DIR="$(dirname "$0")"
LOG_FILE="${LOG_DIR}/install_$(date +"%Y-%m-%d_%H-%M-%S").log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to print a section header
print_header() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║ ${1} ${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print a configuration summary (robust formatting)
print_summary() {
  local hostname="$1" gpuprofile="$2" user="$3" tz="$4" layout="$5" variant="$6" console="$7"
  local v
  v="${variant:-none}"
  printf "%b\n" "${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  printf "%b\n" "${CYAN}║                 📋 Installation Configuration Summary                 ║${NC}"
  printf "%b\n" "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
  printf "%b\n" "${CYAN}║  🖥️  Hostname:        ${BLUE}${hostname}${NC}"
  printf "%b\n" "${CYAN}║  🎮 GPU Profile:      ${BLUE}${gpuprofile}${NC}"
  printf "%b\n" "${CYAN}║  👤 System Username:  ${BLUE}${user}${NC}"
  printf "%b\n" "${CYAN}║  🌐 Timezone:         ${BLUE}${tz}${NC}"
  printf "%b\n" "${CYAN}║  ⌨️  Keyboard Layout:  ${BLUE}${layout}${NC}"
  printf "%b\n" "${CYAN}║  ⌨️  Keyboard Variant: ${BLUE}${v}${NC}"
  printf "%b\n" "${CYAN}║  🖥️  Console Keymap:   ${BLUE}${console:-$layout}${NC}"
  printf "%b\n" "${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print an error message
print_error() {
  echo -e "${RED}Error: ${1}${NC}"
}

# Function to print a success banner
print_success_banner() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                 ZaneyOS Installation Successful!                      ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}║   Please reboot your system for changes to take full effect.          ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print a failure banner
print_failure_banner() {
  echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║                 ZaneyOS Installation Failed!                          ║${NC}"
  echo -e "${RED}║                                                                       ║${NC}"
  echo -e "${RED}║   Please review the log file for details:                             ║${NC}"
  echo -e "${RED}║   ${LOG_FILE}                                                        ║${NC}"
  echo -e "${RED}║                                                                       ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

# Check for required tools
print_header "Verifying System Requirements"

if ! command -v git &>/dev/null; then
  print_error "Git is not installed."
  echo -e "Please install git and pciutils, then re-run the install script."
  echo -e "Example: nix-shell -p git pciutils"
  exit 1
fi

if ! command -v lspci &>/dev/null; then
  print_error "pciutils is not installed."
  echo -e "Please install git and pciutils, then re-run the install script."
  echo -e "Example: nix-shell -p git pciutils"
  exit 1
fi

if [ -n "$(grep -i nixos </etc/os-release)" ]; then
  echo -e "${GREEN}Verified this is NixOS.${NC}"
else
  print_error "This is not NixOS or the distribution information is not available."
  exit 1
fi

# Ensure sbin paths available (parted, mkfs.*)
for p in /usr/sbin /sbin /usr/local/sbin /run/current-system/sw/bin; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) :;; *) PATH="$p:$PATH";; esac
done
export PATH

# Check additional dependencies for disk operations
req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mount umount wipefs blkid; do
  req "$dep"
done

# Partition name helper
part_names_for_disk() {
  local d="$1"; local p1 p2
  if [[ "$d" == *nvme* ]] || [[ "$d" == *mmcblk* ]]; then p1="${d}p1"; p2="${d}p2"; else p1="${d}1"; p2="${d}2"; fi
  echo "$p1 $p2"
}

# Detect if any mountpoints exist under a disk (disk or its partitions)
any_mounts_under() {
  local d="$1"
  lsblk -rno MOUNTPOINTS "$d" 2>/dev/null | awk '($0!="" && $0!="-") {found=1; exit} END{exit !found}'
}

# Disk selection helper (single disk)
select_disk() {
  echo >&2
  echo "Available disks:" >&2
  # Build a numbered list for safer selection (handles virtio: vda)
  mapfile -t DISK_ROWS < <(lsblk -dn -o NAME,SIZE,TYPE,MODEL | awk '$3=="disk" {m=$4; if (m=="") m="-"; printf "%s\t%s\t%s\n", $1,$2,m}')
  if [ "${#DISK_ROWS[@]}" -eq 0 ]; then
    echo "No disks detected. Are you running in a VM without storage, or missing permissions?" >&2
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
  printf "Select disk by number (1-%d) or enter device path (/dev/sdX, /dev/vdX, /dev/nvmeXnY): " "${#DISK_ROWS[@]}" >&2
  local choice
  # Read from controlling terminal to avoid capturing prompts when using command substitution
  if [ -t 0 ]; then
    read -r choice
  else
    read -r choice </dev/tty
  fi
  local disk
  if [[ "$choice" =~ ^/dev/ ]]; then
    disk="$choice"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DISK_ROWS[@]}" ]; then
    local sel_row sel_name
    sel_row="${DISK_ROWS[$((choice-1))]}"
    sel_name=$(echo "$sel_row" | awk '{print $1}')
    disk="/dev/$sel_name"
  else
    echo "Invalid selection: $choice" >&2
    exit 1
  fi
  [ -b "$disk" ] || { echo "Not a block device: $disk" >&2; exit 1; }
  # Return the selected disk on stdout only
  echo "$disk"
}

# Format/mount for each filesystem
prep_btrfs() {
  req mkfs.btrfs; req btrfs
  local disk="$1"
  printf '\nPartitioning %s ...\n' "$disk"
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart primary btrfs 1025MiB 100%
  # Ensure the kernel has created partition nodes
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
  req mkfs.ext4
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
  req mkfs.xfs
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

print_header "Initial Setup"

echo -e "Default options are in brackets []"
echo -e "Just press enter to select the default"
sleep 2

echo -e "${GREEN}Current directory: $(pwd)${NC}"

print_header "User Configuration"

# Prompt for username (for the installed user account)
installusername=$(echo $USER)
echo -e "Current user: ${GREEN}$installusername${NC}"
read -rp "Enter username for the new system [ $installusername ]: " systemUsername
if [ -z "$systemUsername" ]; then
  systemUsername="$installusername"
fi
echo -e "${GREEN}✓ System username set to: $systemUsername${NC}"

# Prompt for user password
USER_HASH=""
ROOT_HASH=""
if command -v openssl >/dev/null 2>&1; then
  # User password
  while true; do
    read -rs -p "Password for user '$systemUsername': " USER_PW1; echo >&2
    read -rs -p "Confirm password for '$systemUsername': " USER_PW2; echo >&2
    if [ "$USER_PW1" != "$USER_PW2" ]; then
      echo -e "${RED}Passwords do not match. Please try again.${NC}" >&2
      continue
    fi
    USER_HASH=$(printf %s "$USER_PW1" | openssl passwd -6 -stdin)
    unset USER_PW1 USER_PW2
    break
  done

  # Root password
  echo ""
  echo -e "${YELLOW}Setting root password (for system administration):${NC}"
  while true; do
    read -rs -p "Password for root: " ROOT_PW1; echo >&2
    read -rs -p "Confirm password for root: " ROOT_PW2; echo >&2
    if [ "$ROOT_PW1" != "$ROOT_PW2" ]; then
      echo -e "${RED}Passwords do not match. Please try again.${NC}" >&2
      continue
    fi
    ROOT_HASH=$(printf %s "$ROOT_PW1" | openssl passwd -6 -stdin)
    unset ROOT_PW1 ROOT_PW2
    break
  done
else
  echo -e "${YELLOW}Warning: openssl not found; user '$systemUsername' and root will be created without passwords.${NC}"
  echo -e "${YELLOW}You can set passwords after first boot.${NC}" >&2
fi

print_header "Filesystem Selection"

echo -e "${CYAN}Select filesystem:${NC}"
echo "  1) Btrfs (with subvolumes & compression)"
echo "  2) ext4  (stable & reliable)"
echo "  3) XFS   (high-performance)"
read -r -p "Choice [1-3]: " FS_CHOICE
case "${FS_CHOICE:-1}" in
  1) FS="btrfs" ;;
  2) FS="ext4" ;;
  3) FS="xfs" ;;
  *) echo "Invalid choice" >&2; exit 1 ;;
esac
echo -e "${GREEN}✓ Filesystem set to: $FS${NC}"

print_header "Disk Selection"

DISK=$(select_disk)
echo
echo -e "${YELLOW}WARNING: This will DESTROY ALL data on $DISK${NC}"
read -r -p "Type 'INSTALL' to proceed (or anything else to abort): " ok
[ "$ok" = "INSTALL" ] || { echo -e "${RED}Installation aborted.${NC}"; exit 1; }

echo -e "${BLUE}Checking if disk is mounted...${NC}"
if any_mounts_under "$DISK"; then
  echo -e "${RED}Device appears mounted (or has mounted partitions). Please unmount first:${NC}"
  lsblk -rno NAME,MOUNTPOINTS "$DISK" | sed 's/^/  /' >&2 || true
  exit 1
fi

echo -e "${BLUE}Preparing disk with $FS filesystem...${NC}"
case "$FS" in
  btrfs) prep_btrfs "$DISK" ;;
  ext4)  prep_ext4  "$DISK" ;;
  xfs)   prep_xfs   "$DISK" ;;
  *) echo "Unsupported FS: $FS" >&2; exit 1 ;;
esac

echo -e "${GREEN}✓ Disk prepared successfully${NC}"
echo

print_header "Generating Hardware Configuration"
echo -e "${BLUE}Running nixos-generate-config...${NC}"
nixos-generate-config --root /mnt
echo -e "${GREEN}✓ Hardware configuration generated${NC}"
echo

print_header "Hostname Configuration"

# Critical warning about using "default" as hostname
echo -e "${RED}⚠️  IMPORTANT WARNING: Do NOT use 'default' as your hostname!${NC}"
echo -e "${RED}   The 'default' hostname is a template and will be overwritten during updates.${NC}"
echo -e "${RED}   This will cause you to lose your configuration!${NC}"
echo ""
echo -e "💡 Suggested hostnames: my-desktop, gaming-rig, workstation, nixos-laptop"
read -rp "Enter Your New Hostname: [ my-desktop ] " hostName
if [ -z "$hostName" ]; then
  hostName="my-desktop"
fi

# Double-check if user accidentally entered "default"
if [ "$hostName" = "default" ]; then
  echo -e "${RED}❌ Error: You cannot use 'default' as hostname. Please choose a different name.${NC}"
  read -rp "Enter a different hostname: " hostName
  if [ -z "$hostName" ] || [ "$hostName" = "default" ]; then
    echo -e "${RED}Setting hostname to 'my-desktop' to prevent configuration loss.${NC}"
    hostName="my-desktop"
  fi
fi

echo -e "${GREEN}✓ Hostname set to: $hostName${NC}"

print_header "GPU Profile Detection"

# Attempt automatic detection
DETECTED_PROFILE=""

has_nvidia=false
has_intel=false
has_amd=false
has_vm=false

if lspci | grep -qi 'vga\|3d'; then
  while read -r line; do
    if echo "$line" | grep -qi 'nvidia'; then
      has_nvidia=true
    elif echo "$line" | grep -qi 'amd'; then
      has_amd=true
    elif echo "$line" | grep -qi 'intel'; then
      has_intel=true
    elif echo "$line" | grep -qi 'virtio\|vmware'; then
      has_vm=true
    fi
  done < <(lspci | grep -i 'vga\|3d')

  if $has_vm; then
    DETECTED_PROFILE="vm"
  elif $has_nvidia && $has_intel; then
    DETECTED_PROFILE="nvidia-laptop"
  elif $has_nvidia && $has_amd; then
    DETECTED_PROFILE="amd-hybrid"
  elif $has_nvidia; then
    DETECTED_PROFILE="nvidia"
  elif $has_amd; then
    DETECTED_PROFILE="amd"
  elif $has_intel; then
    DETECTED_PROFILE="intel"
  fi
fi

# Handle detected profile or fall back to manual input
if [ -n "$DETECTED_PROFILE" ]; then
  profile="$DETECTED_PROFILE"
  echo -e "${GREEN}Detected GPU profile: $profile${NC}"
  read -p "Correct? (Y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}GPU profile not confirmed. Falling back to manual selection.${NC}"
    profile="" # Clear profile to force manual input
  fi
fi

# If profile is still empty (either not detected or not confirmed), prompt manually
if [ -z "$profile" ]; then
  echo -e "${RED}Automatic GPU detection failed or no specific profile found.${NC}"
  read -rp "Enter Your Hardware Profile (GPU)
Options:
[ amd ]
    nvidia
    nvidia-laptop
    amd-hybrid
    intel
    vm
Please type out your choice: " profile
  if [ -z "$profile" ]; then
    profile="amd"
  fi
  echo -e "${GREEN}Selected GPU profile: $profile${NC}"
fi

print_header "Repository Setup"

mkdir -p /mnt/etc/nixos

print_header "Cloning ZaneyOS Repository"
echo -e "${BLUE}Cloning ZaneyOS from GitLab (branch: zos-next)...${NC}"
if [ -d "/mnt/etc/nixos/zaneyos" ]; then
  echo -e "${YELLOW}Removing existing ZaneyOS installation${NC}"
  rm -rf /mnt/etc/nixos/zaneyos
fi
git clone https://gitlab.com/zaney/zaneyos.git -b zos-next --depth=1 /mnt/etc/nixos/zaneyos
cd /mnt/etc/nixos/zaneyos || exit 1
echo -e "${GREEN}✓ ZaneyOS cloned successfully${NC}"

print_header "Git Configuration"
echo "👤 Setting up git configuration for version control:"
echo "  This is needed for system updates and configuration management."
echo ""
echo -e "Using system username for git: ${GREEN}$systemUsername${NC}"
read -rp "Enter your full name for git commits [ $systemUsername ]: " gitUsername
if [ -z "$gitUsername" ]; then
  gitUsername="$systemUsername"
fi

echo "📧 Examples: john@example.com, jane.doe@company.org"
read -rp "Enter your email address for git commits [ $installusername@example.com ]: " gitEmail
if [ -z "$gitEmail" ]; then
  gitEmail="$installusername@example.com"
fi

echo -e "${GREEN}✓ Git name: $gitUsername${NC}"
echo -e "${GREEN}✓ Git email: $gitEmail${NC}"

print_header "Timezone Configuration"
echo "🌎 Common timezones:"
echo "  • US: America/New_York, America/Chicago, America/Denver, America/Los_Angeles"
echo "  • Europe: Europe/London, Europe/Berlin, Europe/Paris, Europe/Rome"
echo "  • Asia: Asia/Tokyo, Asia/Shanghai, Asia/Seoul, Asia/Kolkata"
echo "  • Australia: Australia/Sydney, Australia/Melbourne"
echo "  • UTC (Universal): UTC"
read -rp "Enter your timezone [ America/New_York ]: " timezone
if [ -z "$timezone" ]; then
  timezone="America/New_York"
fi
echo -e "${GREEN}✓ Timezone set to: $timezone${NC}"

print_header "Keyboard Layout Configuration"
echo "🌍 Common keyboard layouts:"
echo "  • us (US English) - default"
echo "  • us-intl (US International)"
echo "  • uk (UK English)"
echo "  • de (German)"
echo "  • fr (French)"
echo "  • es (Spanish)"
echo "  • it (Italian)"
echo "  • ru (Russian)"
echo "  • dvorak (Dvorak)"
read -rp "Enter your keyboard layout: [ us ] " keyboardLayout
if [ -z "$keyboardLayout" ]; then
  keyboardLayout="us"
fi
echo -e "${GREEN}✓ Keyboard layout set to: $keyboardLayout${NC}"

print_header "Keyboard Variant Configuration"
# Suggest a variant when user typed a variant-like layout
variant_suggestion=""
case "$keyboardLayout" in
dvorak | colemak | workman | intl | us-intl)
  variant_suggestion="$keyboardLayout"
  ;;
*) ;;
esac
read -rp "Enter your keyboard variant (e.g., dvorak) [ $variant_suggestion ]: " keyboardVariant
keyboardVariant="${keyboardVariant:-$variant_suggestion}"

# Normalize layout/variant to avoid accidentally forcing US for non-US layouts
# - Accept uppercase inputs; treat BR/DE/FR/ES/IT/RU/UK in variant field as layout
# - Map us-intl/intl and dvorak/colemak/workman to layout=us + appropriate variant
keyboardLayout=$(echo "$keyboardLayout" | tr '[:upper:]' '[:lower:]')
keyboardVariant=$(echo "$keyboardVariant" | tr '[:upper:]' '[:lower:]')

case "$keyboardLayout" in
us-intl | intl)
  keyboardLayout="us"
  if [ -z "$keyboardVariant" ]; then keyboardVariant="intl"; fi
  ;;
dvorak | colemak | workman)
  if [ -z "$keyboardVariant" ]; then keyboardVariant="$keyboardLayout"; fi
  keyboardLayout="us"
  ;;
*) ;;
esac

# If a layout accidentally ended up in the variant field, fix it
if [[ "$keyboardVariant" =~ ^(us|br|de|fr|es|it|ru|uk)$ ]]; then
  keyboardLayout="$keyboardVariant"
  keyboardVariant=""
fi

if [ -z "$keyboardVariant" ]; then
  echo -e "${GREEN}✓ Keyboard variant set to: none${NC}"
else
  echo -e "${GREEN}✓ Keyboard variant set to: $keyboardVariant${NC}"
fi

print_header "Console Keymap Configuration"
echo "⌨️  Console keymap (usually matches your keyboard layout):"
echo "  Most common: us, uk, de, fr, es, it, ru"
# Smart default: use keyboard layout as console keymap default if it's a common one
defaultConsoleKeyMap="$keyboardLayout"
if [[ ! "$keyboardLayout" =~ ^(us|uk|de|fr|es|it|ru|us-intl|dvorak)$ ]]; then
  defaultConsoleKeyMap="us"
fi
read -rp "Enter your console keymap: [ $defaultConsoleKeyMap ] " consoleKeyMap
if [ -z "$consoleKeyMap" ]; then
  consoleKeyMap="$defaultConsoleKeyMap"
fi
echo -e "${GREEN}✓ Console keymap set to: $consoleKeyMap${NC}"

print_header "Configuring Host and Profile"
mkdir -p hosts/"$hostName"
cp hosts/default/*.nix hosts/"$hostName"

# Show a nice summary and ask for confirmation before making changes
echo ""
print_summary "$hostName" "$profile" "$systemUsername" "$timezone" "$keyboardLayout" "$keyboardVariant" "$consoleKeyMap"
echo ""
echo -e "${YELLOW}Please review the configuration above.${NC}"
printf "%b" "${YELLOW}Continue with installation? (Y/N): ${NC}"
read -r REPLY
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}Installation cancelled.${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Configuration accepted. Starting installation...${NC}"
echo ""
echo -e "${BLUE}Updating configuration files...${NC}"

# Update flake.nix safely without removing existing hosts
cp ./flake.nix ./flake.nix.bak

# 1) Update username if present
sed -i -E "s|^[[:space:]]*username[[:space:]]*=[[:space:]]*\"[^\"]*\";|    username = \"${systemUsername}\";|" ./flake.nix

# 2) Ensure the new host is listed in the hosts array (append if missing)
awk -v h="$hostName" '
  BEGIN { in_hosts=0; seen=0 }
  /^\s*hosts\s*=\s*\[/ { in_hosts=1 }
  in_hosts && /"[^"]+"/ {
    if (index($0, "\"" h "\"") > 0) seen=1
  }
  in_hosts && /\];/ {
    if (!seen) print "      \"" h "\""
    in_hosts=0
  }
  { print }
' ./flake.nix > ./flake.nix.tmp && mv ./flake.nix.tmp ./flake.nix

# (quiet) flake updated

# Update timezone in system.nix (robust quoting via Python helper)
cp ./modules/core/system.nix ./modules/core/system.nix.bak
python3 ./scripts/update_timezone.py ./modules/core/system.nix "$timezone" || {
  print_error "Failed to update time.timeZone in modules/core/system.nix";
  exit 1;
}
rm ./modules/core/system.nix.bak

# Update variables in host file; support both old style and new zaneyos options block
cp ./hosts/$hostName/variables.nix ./hosts/$hostName/variables.nix.bak
python3 ./scripts/update_vars.py "./hosts/$hostName/variables.nix" \
  "$gitUsername" "$gitEmail" "$hostName" "$profile" "$keyboardLayout" "$keyboardVariant" "$consoleKeyMap" || {
  print_error "Failed to update hosts/$hostName/variables.nix";
  echo "Check the file exists and the script at ./scripts/update_vars.py is present.";
  exit 1;
}
rm ./hosts/$hostName/variables.nix.bak

echo "Configuration files updated successfully!"

print_header "Git Configuration"
git config --global user.name "$gitUsername"
git config --global user.email "$gitEmail"
git add . --all
git config --global --unset-all user.name
git config --global --unset-all user.email
echo -e "${GREEN}✓ Committed initial configuration to git${NC}"

print_header "Preparing Flake for Installation"
echo -e "${BLUE}Removing git metadata to treat flake as local path...${NC}"
rm -rf .git .gitmodules
echo -e "${GREEN}✓ Flake prepared${NC}"
echo

print_header "Initiating NixOS Installation"
printf "%s" "Ready to run nixos-install? [y/N]: "
read -r REPLY
if ! [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo -e "${RED}Installation cancelled.${NC}"
  exit 1
fi

echo
echo -e "${BLUE}Running nixos-install with ZaneyOS flake...${NC}"
# Use nixos-install instead of nixos-rebuild to avoid filling live system's /nix/store
# This builds everything to /mnt instead of the live system
nixos-install --flake /mnt/etc/nixos/zaneyos#${hostName} --option accept-flake-config true

# Check the exit status of the last command (nixos-install)
if [ $? -eq 0 ]; then
  print_header "Post-Installation Setup"
  
  # Copy ZaneyOS to user home for convenient post-install access and edits
  echo -e "${BLUE}Copying ZaneyOS to user home...${NC}"
  mkdir -p /mnt/home/$systemUsername
  rm -rf /mnt/home/$systemUsername/zaneyos
  cp -r /mnt/etc/nixos/zaneyos /mnt/home/$systemUsername/zaneyos
  # Fix ownership so user can edit/rebuild if needed
  chroot /mnt chown -R $systemUsername:users /home/$systemUsername/zaneyos 2>/dev/null || true
  echo -e "${GREEN}✓ ZaneyOS copied to /home/$systemUsername/zaneyos${NC}"
  echo
  
  print_header "Setting User and Root Passwords"
  
  # Set user password if provided
  if [ -n "$USER_HASH" ]; then
    echo -e "${BLUE}Setting password for user '$systemUsername'...${NC}"
    echo '${systemUsername}:${USER_HASH}' | chroot /mnt chpasswd -e 2>/dev/null || true
  fi
  
  # Set root password if provided
  if [ -n "$ROOT_HASH" ]; then
    echo -e "${BLUE}Setting password for root...${NC}"
    echo 'root:${ROOT_HASH}' | chroot /mnt chpasswd -e 2>/dev/null || true
  fi
  
  print_success_banner
else
  print_failure_banner
fi
