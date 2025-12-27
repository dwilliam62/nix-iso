#!/usr/bin/env bash

######################################
# Install script for hyprland-btw Hyprland config
# Adapted for nix-iso recovery environment
# Author: Don Williams
# Based on: hyprland-btw install.sh and ZaneyOS installer
#######################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &> /dev/null && pwd)"
LOG_FILE="${SCRIPT_DIR}/install-hyprland-btw_$(date +"%Y-%m-%d_%H-%M-%S").log"

mkdir -p "$SCRIPT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║ ${1} ${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_error() {
  echo -e "${RED}Error: ${1}${NC}"
}

print_summary() {
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║          hyprland-btw Installation Configuration Summary              ║${NC}"
  echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║  🖥️  Hostname:        ${BLUE}${1}${NC}"
  echo -e "${CYAN}║  🎮 GPU Profile:      ${BLUE}${2}${NC}"
  echo -e "${CYAN}║  👤 System Username:  ${BLUE}${3}${NC}"
  echo -e "${CYAN}║  🌐 Timezone:         ${BLUE}${4}${NC}"
  echo -e "${CYAN}║  ⌨️  Keyboard Layout:  ${BLUE}${5}${NC}"
  echo -e "${CYAN}║  🖥️  Console Keymap:   ${BLUE}${6}${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_success_banner() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║        hyprland-btw Hyprland configuration applied successfully!      ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}║   Please reboot your system for changes to take full effect.          ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_failure_banner() {
  echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║         hyprland-btw installation failed during nixos-rebuild.        ║${NC}"
  echo -e "${RED}║                                                                       ║${NC}"
  echo -e "${RED}║   Please review the log file for details:                             ║${NC}"
  echo -e "${RED}║   ${LOG_FILE}${NC}"
  echo -e "${RED}║                                                                       ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

prompt_yes_no() {
  # Usage: prompt_yes_no "Question?" [default]
  # default: Y or N (case-insensitive). If omitted, default is Y.
  local question="$1"
  local def="${2:-Y}"
  local ans=""
  local suffix="[Y/n]"
  if [[ "$def" =~ ^[Nn]$ ]]; then suffix="[y/N]"; fi
  while true; do
    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
      printf "%s %s " "$question" "$suffix" > /dev/tty
      IFS= read -r ans < /dev/tty || ans=""
    else
      printf "%s %s " "$question" "$suffix"
      IFS= read -r ans || ans=""
    fi
    # Trim whitespace
    ans="${ans//[$'\t\r\n ']}"
    if [[ -z "$ans" ]]; then
      if [[ "$def" =~ ^[Yy]$ ]]; then return 0; else return 1; fi
    fi
    case "${ans,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

is_valid_username() {
  # POSIX-ish: start with [a-z_], then [a-z0-9_-]; limit to 32 chars
  local u="$1"
  [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

ensure_username() {
  # Validates and confirms username
  while true; do
    if [ -z "$userName" ]; then
      userName="$defaultUserName"
    fi
    if ! is_valid_username "$userName"; then
      echo -e "${RED}Invalid username '$userName'. Use lowercase letters, digits, '_' or '-', starting with a letter or '_' (max 32).${NC}"
      printf "Enter primary username for this system [%s]: " "$defaultUserName"
      IFS= read -r userName
      continue
    fi
    if id -u "$userName" >/dev/null 2>&1 || getent passwd "$userName" >/dev/null 2>&1; then
      echo -e "${GREEN}User '$userName' exists on this system.${NC}"
      break
    fi
    echo -e "${YELLOW}User '$userName' does not currently exist on this system.${NC}"
    echo -e "${YELLOW}It will be created during nixos-rebuild (users.users.\"$userName\" is defined).${NC}"
    if prompt_yes_no "Proceed with creating '$userName' on switch?" N; then
      break
    fi
    # Reprompt for a different username
    printf "Enter a different username [%s]: " "$defaultUserName"
    IFS= read -r userName
  done
}

read_password() {
  # Usage: read_password "Prompt" var_name
  local prompt="$1"
  local var_name="$2"
  local password1 password2
  while true; do
    read -sp "$prompt: " password1
    echo
    read -sp "Confirm password: " password2
    echo
    if [ "$password1" = "$password2" ]; then
      eval "$var_name=\"$password1\""
      return 0
    else
      echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
  done
}

NONINTERACTIVE=0

print_usage() {
  cat <<EOF
Usage: $0 [--non-interactive]

Options:
  --non-interactive  Do not prompt; accept defaults and proceed automatically
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive)
      NONINTERACTIVE=1
      shift 1
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

print_header "Verifying System Requirements"

if ! command -v git &>/dev/null; then
  print_error "Git is not installed."
  echo -e "Please install git, then re-run the install script."
  echo -e "Example: nix-shell -p git"
  exit 1
fi

if ! command -v lspci &>/dev/null; then
  print_error "pciutils (lspci) is not installed."
  echo -e "Please install pciutils, then re-run the install script."
  echo -e "Example: nix-shell -p pciutils"
  exit 1
fi

if [ -n "$(grep -i nixos </etc/os-release || true)" ]; then
  echo -e "${GREEN}Verified this is NixOS.${NC}"
else
  print_error "This is not NixOS or the distribution information is not available."
  exit 1
fi

print_header "GPU Profile Detection"

# GPU profile detection (VM / amd / intel / nvidia)
GPU_PROFILE=""
has_nvidia=false
has_intel=false
has_amd=false
has_vm=false

if lspci | grep -qi 'vga\|3d'; then
  while read -r line; do
    if   echo "$line" | grep -qi 'nvidia'; then
      has_nvidia=true
    elif echo "$line" | grep -qi 'amd'; then
      has_amd=true
    elif echo "$line" | grep -qi 'intel'; then
      has_intel=true
    elif echo "$line" | grep -qi 'virtio\|vmware'; then
      has_vm=true
    fi
  done < <(lspci | grep -i 'vga\|3d')

  if   $has_vm; then
    GPU_PROFILE="vm"
  elif $has_nvidia && $has_intel; then
    GPU_PROFILE="nvidia"  # treat hybrid laptop as primary NVIDIA
  elif $has_nvidia; then
    GPU_PROFILE="nvidia"
  elif $has_amd; then
    GPU_PROFILE="amd"
  elif $has_intel; then
    GPU_PROFILE="intel"
  fi
fi

if [ -n "$GPU_PROFILE" ]; then
  echo -e "${GREEN}Detected GPU profile: $GPU_PROFILE${NC}"
  if [ $NONINTERACTIVE -eq 1 ]; then
    echo -e "Non-interactive: accepting detected GPU profile"
  else
    if ! prompt_yes_no "Is this GPU profile correct?" Y; then
      echo -e "${YELLOW}GPU profile not confirmed. Falling back to manual selection.${NC}"
      GPU_PROFILE=""
    fi
  fi
fi

if [ -z "$GPU_PROFILE" ]; then
  if [ $NONINTERACTIVE -eq 1 ]; then
    GPU_PROFILE="vm"
    echo -e "Non-interactive: defaulting GPU profile to $GPU_PROFILE"
  else
    echo -e "${YELLOW}Automatic GPU detection failed or no specific profile found.${NC}"
    echo -e "Available GPU profiles: amd | intel | nvidia | vm"
    read -rp "Enter GPU profile [ vm ]: " GPU_PROFILE
    if [ -z "$GPU_PROFILE" ]; then
      GPU_PROFILE="vm"
    fi
  fi
fi

print_header "System Configuration"

defaultTimeZone="America/New_York"
defaultHostName="hyprland-btw"
defaultUserName="${USER:-nixos}"
defaultKeyboardLayout="us"
defaultConsoleKeyMap="us"

if [ $NONINTERACTIVE -eq 1 ]; then
  timeZone="$defaultTimeZone"
  hostName="$defaultHostName"
  userName="$defaultUserName"
  keyboardLayout="$defaultKeyboardLayout"
  consoleKeyMap="$defaultConsoleKeyMap"
  echo -e "Non-interactive: defaulting timezone to $timeZone"
  echo -e "Non-interactive: defaulting hostname to $hostName"
  echo -e "Non-interactive: defaulting username to $userName"
  echo -e "Non-interactive: defaulting keyboard layout to $keyboardLayout"
  echo -e "Non-interactive: defaulting console keymap to $consoleKeyMap"
else
  echo "Default options are in brackets []"
  echo "Just press enter to select the default"
  echo ""

  read -rp "Enter your timezone [${defaultTimeZone}]: " timeZone
  if [ -z "$timeZone" ]; then
    timeZone="$defaultTimeZone"
  fi

  echo ""
  read -rp "Enter hostname for this system [${defaultHostName}]: " hostName
  if [ -z "$hostName" ]; then
    hostName="$defaultHostName"
  fi

  echo ""
  read -rp "Enter primary username for this system [${defaultUserName}]: " userName
  ensure_username

  echo ""
  echo "Common keyboard layouts: us, uk, de, fr, es, it, dvorak, colemak"
  read -rp "Enter your keyboard layout [ ${defaultKeyboardLayout} ]: " keyboardLayout
  if [ -z "$keyboardLayout" ]; then
    keyboardLayout="$defaultKeyboardLayout"
  fi

  echo ""
  echo "Console keymap usually matches keyboard layout"
  read -rp "Enter your console keymap [ ${keyboardLayout} ]: " consoleKeyMap
  if [ -z "$consoleKeyMap" ]; then
    consoleKeyMap="$keyboardLayout"
  fi
fi

print_header "Clone hyprland-btw Repository"

CLONE_DIR="$HOME/hyprland-btw"
if [ -d "$CLONE_DIR" ]; then
  if [ $NONINTERACTIVE -eq 1 ]; then
    echo -e "${YELLOW}hyprland-btw directory exists at ${CLONE_DIR}. Using existing installation.${NC}"
  else
    if ! prompt_yes_no "hyprland-btw directory exists. Use existing installation?" Y; then
      backupname=$(date +"%Y-%m-%d-%H-%M-%S")
      if [ -d "$HOME/.config/hyprland-btw-backups" ]; then
        mv "$CLONE_DIR" "$HOME/.config/hyprland-btw-backups/hyprland-btw-${backupname}"
      else
        mkdir -p "$HOME/.config/hyprland-btw-backups"
        mv "$CLONE_DIR" "$HOME/.config/hyprland-btw-backups/hyprland-btw-${backupname}"
      fi
      echo -e "${GREEN}Backed up existing installation to ~/.config/hyprland-btw-backups/hyprland-btw-${backupname}${NC}"
      git clone https://github.com/dwilliam62/hyprland-btw.git "$CLONE_DIR"
    fi
  fi
else
  echo -e "${GREEN}Cloning hyprland-btw repository...${NC}"
  git clone https://github.com/dwilliam62/hyprland-btw.git "$CLONE_DIR"
fi

cd "$CLONE_DIR" || exit 1
echo -e "${GREEN}Working directory: $(pwd)${NC}"

# Show configuration summary
echo ""
print_summary "$hostName" "$GPU_PROFILE" "$userName" "$timeZone" "$keyboardLayout" "$consoleKeyMap"
echo ""

if [ $NONINTERACTIVE -eq 1 ]; then
  echo -e "Non-interactive: proceeding with installation"
else
  echo -e "${YELLOW}Please review the configuration above.${NC}"
  if ! prompt_yes_no "Continue with installation?" Y; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 1
  fi
fi

echo ""
echo -e "${GREEN}✓ Configuration accepted. Starting installation...${NC}"
echo ""

# Patch configuration.nix with chosen timezone, hostname, username, and layouts
echo -e "${BLUE}Updating configuration.nix...${NC}"
sed -i "s/time\.timeZone = \"[^\"]*\";/time.timeZone = \"$timeZone\";/" ./configuration.nix
sed -i "s/hostName = \"[^\"]*\";/hostName = \"$hostName\";/" ./configuration.nix

# Determine the currently-declared primary user in configuration.nix
CURRENT_DECLARED_USER=$(sed -n 's/.*users\.users\."\([^"]*\)".*/\1/p' ./configuration.nix | head -n1)
if [ -z "$CURRENT_DECLARED_USER" ]; then
  CURRENT_DECLARED_USER="dwilliams"
fi

# If the chosen username differs, add a new users.users block and enable mutableUsers
if [ "$userName" != "$CURRENT_DECLARED_USER" ]; then
  echo -e "${YELLOW}Primary user changed: ${CURRENT_DECLARED_USER} -> ${userName}. Adding new user entry.${NC}"
  # Ensure users.mutableUsers = true so undeclared users are not removed
  if grep -q "users\.mutableUsers" ./configuration.nix; then
    sed -i 's/users\.mutableUsers = .*/users.mutableUsers = true;/' ./configuration.nix
  else
    sed -i '/nix\.settings\.experimental-features/a\  users.mutableUsers = true;' ./configuration.nix
  fi
  # Add new user entry if it doesn't already exist
  if ! grep -q "users\.users\.\"$userName\"" ./configuration.nix; then
    # Find the closing brace of the first users.users block and insert after it
    awk -v newuser="$userName" '
      /users\.users\."[^"]*" = \{/,/^  \};/ {
        print
        if (/^  \};$/ && !added) {
          print ""
          print "  users.users.\"" newuser "\" = {"
          print "    isNormalUser = true;"
          print "    extraGroups = [\"wheel\" \"input\"];"
          print "    shell = pkgs.zsh;"
          print "  };"
          added=1
        }
        next
      }
      {print}
    ' ./configuration.nix > ./configuration.nix.tmp && mv ./configuration.nix.tmp ./configuration.nix
  fi
else
  echo -e "${GREEN}Primary username unchanged (${userName}).${NC}"
fi

# Update console keymap and XKB layout
sed -i "s/console\.keyMap = \"[^\"]*\";/console.keyMap = \"$consoleKeyMap\";/" ./configuration.nix
sed -i "s/xserver\.xkb\.layout = \"[^\"]*\";/xserver.xkb.layout = \"$keyboardLayout\";/" ./configuration.nix

# Toggle VM guest services based on GPU profile
if [ "$GPU_PROFILE" = "vm" ]; then
  sed -i "s/vm\.guest-services\.enable = .*/vm.guest-services.enable = true;/" ./configuration.nix
else
  sed -i "s/vm\.guest-services\.enable = .*/vm.guest-services.enable = false;/" ./configuration.nix
fi

# Enable the matching GPU driver module and disable the others
echo -e "${BLUE}Configuring GPU drivers for profile: ${GPU_PROFILE}${NC}"
case "$GPU_PROFILE" in
  amd)
    sed -i "s/drivers\.amdgpu\.enable = .*/drivers.amdgpu.enable = true;/" ./configuration.nix
    sed -i "s/drivers\.intel\.enable = .*/drivers.intel.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.nvidia\.enable = .*/drivers.nvidia.enable = false;/" ./configuration.nix
    ;;
  intel)
    sed -i "s/drivers\.amdgpu\.enable = .*/drivers.amdgpu.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.intel\.enable = .*/drivers.intel.enable = true;/" ./configuration.nix
    sed -i "s/drivers\.nvidia\.enable = .*/drivers.nvidia.enable = false;/" ./configuration.nix
    ;;
  nvidia)
    sed -i "s/drivers\.amdgpu\.enable = .*/drivers.amdgpu.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.intel\.enable = .*/drivers.intel.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.nvidia\.enable = .*/drivers.nvidia.enable = true;/" ./configuration.nix
    ;;
  vm|*)
    sed -i "s/drivers\.amdgpu\.enable = .*/drivers.amdgpu.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.intel\.enable = .*/drivers.intel.enable = false;/" ./configuration.nix
    sed -i "s/drivers\.nvidia\.enable = .*/drivers.nvidia.enable = false;/" ./configuration.nix
    ;;
esac

# Update flake.nix: both nixosConfigurations name AND home-manager username
echo -e "${BLUE}Updating flake.nix...${NC}"
sed -i "s/nixosConfigurations\.hyprland-btw =/nixosConfigurations.$hostName =/" ./flake.nix
sed -i "s|users\.\"[^\"]*\" = import ./home\.nix;|users.\"$userName\" = import ./home.nix;|" ./flake.nix

# Update home.nix
echo -e "${BLUE}Updating home.nix...${NC}"
sed -i "s/\([ ]*\)username = lib\.mkDefault \"[^\"]*\";/\1username = lib.mkDefault \"$userName\";/" ./home.nix
sed -i "s|\([ ]*\)homeDirectory = lib\.mkDefault \"/home/[^\"]*\";|\1homeDirectory = lib.mkDefault \"/home/$userName\";|" ./home.nix

print_header "Hardware Configuration"

TARGET_HW="./hardware-configuration.nix"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"

backup_if_exists() {
  if [ -f "$TARGET_HW" ]; then
    local ts
    ts="$(date +%s)"
    mv "$TARGET_HW" "${TARGET_HW}.backup.${ts}"
    echo -e "${YELLOW}Backed up existing hardware-configuration.nix to ${TARGET_HW}.backup.${ts}${NC}"
  fi
}

copy_from() {
  local src="$1"
  backup_if_exists
  cp "$src" "$TARGET_HW"
  chown "$OWNER_USER":"$OWNER_USER" "$TARGET_HW" 2>/dev/null || true
  echo -e "${GREEN}Wrote $TARGET_HW from $src${NC}"
}

write_from_show() {
  backup_if_exists
  if nixos-generate-config --show-hardware-config > "$TARGET_HW" 2>/dev/null; then
    chown "$OWNER_USER":"$OWNER_USER" "$TARGET_HW" 2>/dev/null || true
    echo -e "${GREEN}Wrote $TARGET_HW from nixos-generate-config --show-hardware-config${NC}"
    return 0
  fi
  return 1
}

ensure_hw_config() {
  # 1) Prefer existing system file
  if [ -f /etc/nixos/hardware-configuration.nix ]; then
    if [ $NONINTERACTIVE -eq 1 ]; then
      echo -e "Non-interactive: using existing /etc/nixos/hardware-configuration.nix"
      copy_from /etc/nixos/hardware-configuration.nix
      return 0
    else
      if prompt_yes_no "Use existing /etc/nixos/hardware-configuration.nix?" Y; then
        copy_from /etc/nixos/hardware-configuration.nix
        return 0
      fi
    fi
  else
    echo -e "${YELLOW}/etc/nixos/hardware-configuration.nix not found.${NC}"
  fi

  # 2) Try generating directly to repo without touching /etc
  if write_from_show; then
    return 0
  fi

  # 3) If inside installer with target mounted at /mnt, try that path
  if [ -f /mnt/etc/nixos/hardware-configuration.nix ]; then
    echo -e "${GREEN}Found /mnt/etc/nixos/hardware-configuration.nix${NC}"
    copy_from /mnt/etc/nixos/hardware-configuration.nix
    return 0
  fi

  # 4) As a fallback, generate into /mnt if present
  local root="/"
  if mountpoint -q /mnt 2>/dev/null; then
    root="/mnt"
  fi
  echo -e "${YELLOW}Generating hardware config with: sudo nixos-generate-config --root ${root}${NC}"
  sudo nixos-generate-config --root "$root"
  if [ -f "$root/etc/nixos/hardware-configuration.nix" ]; then
    copy_from "$root/etc/nixos/hardware-configuration.nix"
    return 0
  fi

  return 1
}

if ensure_hw_config; then
  :
else
  print_error "hardware-configuration.nix could not be created."
  echo -e "Tried: existing /etc, --show-hardware-config, /mnt, and --root fallback."
  exit 1
fi

print_header "User and Root Password Setup"

# Prompt for primary user password
if [ $NONINTERACTIVE -eq 1 ]; then
  echo -e "${YELLOW}Non-interactive mode: skipping password setup. Use 'passwd' after reboot.${NC}"
else
  echo -e "${CYAN}Setting up user and root passwords.${NC}"
  echo ""

  # User password
  echo -e "${CYAN}Enter password for user '${userName}':${NC}"
  read_password "Password" userPassword
  # Note: We cannot set the password during nixos-rebuild in a script.
  # Users will need to use `passwd` after system boots.
  echo -e "${YELLOW}Note: Password will be set after first boot using 'passwd' command.${NC}"
fi

print_header "Pre-build Verification"

echo -e "About to build hyprland-btw configuration with these settings:"
echo -e "  🌍  Timezone:      ${GREEN}$timeZone${NC}"
echo -e "  🖥️  Hostname:       ${GREEN}$hostName${NC}"
echo -e "  👤 Username:       ${GREEN}$userName${NC}"
echo -e "  🎮 GPU Profile:    ${GREEN}$GPU_PROFILE${NC}"
echo -e "  ⌨️  Keyboard Layout: ${GREEN}$keyboardLayout${NC}"
echo ""
echo -e "${YELLOW}This will build and apply your Hyprland configuration.${NC}"
echo ""

if [ $NONINTERACTIVE -eq 1 ]; then
  echo -e "Non-interactive: proceeding with build"
else
  if ! prompt_yes_no "Ready to run initial build?" Y; then
    echo -e "${RED}Build cancelled.${NC}"
    exit 1
  fi
fi

print_header "Running nixos-rebuild (boot)"

echo -e "${BLUE}Building with hostname: $hostName and user: $userName${NC}"
FLAKE_TARGET="#${hostName}"
if sudo nixos-rebuild boot --flake .${FLAKE_TARGET} --option accept-flake-config true --refresh --allow-dirty; then
  print_success_banner
  echo ""
  echo -e "${CYAN}After reboot, set passwords using:${NC}"
  echo -e "  ${GREEN}passwd${NC} (to set your user password)"
  echo -e "  ${GREEN}sudo passwd root${NC} (to set root password)"
  echo ""
  if [ $NONINTERACTIVE -eq 1 ]; then
    echo "Non-interactive: please reboot your system to start using ${hostName}."
  else
    if prompt_yes_no "Reboot now to start using ${hostName}?" N; then
      echo "Rebooting..."
      sudo reboot
    else
      echo "You chose not to reboot now. Please reboot manually when ready."
    fi
  fi
else
  print_failure_banner
  exit 1
fi
