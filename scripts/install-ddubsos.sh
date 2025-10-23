#!/usr/bin/env bash
# Author: Don Williams (aka ddubs)
# Created: 2025-10-23
# Project: https://github.com/dwilliam62/nix-iso
# ddubsOS installer: prepare disk, mount filesystems, and install using the ddubsos flake
# - Prompts for filesystem, disk(s), hostname, username (default: dwilliams)
# - Partitions and formats disk(s) modeled after existing install-* scripts
# - Mounts target and generates hardware-configuration.nix
# - Copies local ddubsos repo (~/ddubsos) into /mnt/etc/nixos/ddubsos (or clones from GitLab if absent)
# - If host exists in repo, updates hosts/<host>/hardware.nix with the generated config, preserving /mnt/nas if present
# - If host does not exist, creates it from hosts/default template and writes hardware.nix
# - Runs nixos-install --flake /mnt/etc/nixos/ddubsos#<host>

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

# Dependencies we will use conditionally per-filesystem as well
req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for dep in lsblk parted mkfs.fat mount umount sed awk tee grep tr cut head tail wc nixos-generate-config nixos-install blkid; do
  req "$dep"
done

LIVE_HWCFG="/mnt/etc/nixos/hardware-configuration.nix"
DDUBS_LOCAL="$HOME/ddubsos"
DDUBS_TARGET_ROOT="/mnt/etc/nixos/ddubsos"
DDUBS_REMOTE="git+https://gitlab.com/dwilliam62/ddubsos"

# Prompt helpers
read_default() {
  local prompt="$1" default="$2" var
  read -r -p "$prompt [$default]: " var || true
  if [ -z "${var}" ]; then echo "$default"; else echo "$var"; fi
}

press_enter() { read -r -p "Press Enter to continue..." _ || true; }

# Return 0 if any mountpoints exist under the given disk (disk or its partitions)
any_mounts_under() {
  local d="$1"
  lsblk -rno MOUNTPOINTS "$d" 2>/dev/null | awk '($0!="" && $0!="-") {found=1; exit} END{exit !found}'
}

# Disk selection helper (single disk)
select_disk() {
  echo
  echo "Scanning for available, unmounted disks ..."
  mapfile -t ALL_DISKS < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}')
  local avail_names=()
  local avail_sizes=()
  local avail_models=()
  for name in "${ALL_DISKS[@]}"; do
    # Skip if any mountpoints exist under this disk (e.g., live USB)
if any_mounts_under "/dev/$name"; then
      continue
    fi
    avail_names+=("$name")
    avail_sizes+=("$(lsblk -dn -o SIZE "/dev/$name")")
    avail_models+=("$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | sed 's/^$/-/')")
  done
  if [ "${#avail_names[@]}" -eq 0 ]; then
    echo "No completely unmounted disks found." >&2
    echo "Hint: the USB you booted from is excluded; select an internal drive." >&2
    return 1
  fi
  local idx=1
  for i in "${!avail_names[@]}"; do
    printf "[%d] /dev/%s  %s  %s\n" "$idx" "${avail_names[$i]}" "${avail_sizes[$i]}" "${avail_models[$i]}"
    idx=$((idx+1))
  done
  echo
  read -r -p "Select disk by number (1-${#avail_names[@]}) or enter device path (/dev/sdX, /dev/vdX, /dev/nvmeXnY): " choice
  local disk
  if [[ "$choice" =~ ^/dev/ ]]; then
    disk="$choice"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#avail_names[@]}" ]; then
    disk="/dev/${avail_names[$((choice-1))]}"
  else
    echo "Invalid selection: $choice" >&2; exit 1
  fi
  [ -b "$disk" ] || { echo "Not a block device: $disk" >&2; exit 1; }
  if command -v blockdev >/dev/null 2>&1 && [ "$(blockdev --getro "$disk" || echo 1)" != 0 ]; then
    echo "Device appears read-only: $disk" >&2; exit 1
  fi
  echo "$disk"
}

# Partition name helper
part_names_for_disk() {
  local d="$1"; local p1 p2
  if [[ "$d" == *nvme* ]] || [[ "$d" == *mmcblk* ]]; then p1="${d}p1"; p2="${d}p2"; else p1="${d}1"; p2="${d}2"; fi
  echo "$p1 $p2"
}

# Format/mount for each filesystem
prep_btrfs() {
  req mkfs.btrfs; req btrfs
  local disk="$1"
  echo "\nPartitioning $disk ..."
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
parted -s "$DISK" mkpart primary btrfs 1025MiB 100%
  # Ensure the kernel has created partition nodes
  command -v partprobe >/dev/null 2>&1 && partprobe "$DISK" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  echo "\nCreating filesystems ..."
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.btrfs -f -L nixos "$P2"
  echo "\nCreating subvolumes ..."
  mkdir -p /mnt
  mount -o subvolid=5 "$P2" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@nix
  btrfs subvolume create /mnt/@snapshots
  umount /mnt
  echo "\nMounting target ..."
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
  echo "\nPartitioning $disk ..."
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
parted -s "$DISK" mkpart primary ext4 1025MiB 100%
  command -v partprobe >/dev/null 2>&1 && partprobe "$DISK" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  echo "\nCreating filesystems ..."
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.ext4 -F -L nixos "$P2"
  echo "\nMounting target ..."
  mkdir -p /mnt
  mount -o noatime "$P2" /mnt
  mkdir -p /mnt/{home,nix,boot,.snapshots}
  mount "$P1" /mnt/boot
}

prep_xfs() {
  req mkfs.xfs
  local disk="$1"
  echo "\nPartitioning $disk ..."
  wipefs -af "$disk"
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
  parted -s "$disk" set 1 esp on
parted -s "$DISK" mkpart primary xfs 1025MiB 100%
  command -v partprobe >/dev/null 2>&1 && partprobe "$DISK" || true
  command -v udevadm >/dev/null 2>&1 && udevadm settle || sleep 1
  read -r P1 P2 < <(part_names_for_disk "$disk")
  echo "\nCreating filesystems ..."
  mkfs.fat -F32 -n EFI "$P1"
  mkfs.xfs -f -L nixos "$P2"
  echo "\nMounting target ..."
  mkdir -p /mnt
  mount -o noatime "$P2" /mnt
  mkdir -p /mnt/{home,nix,boot,.snapshots}
  mount "$P1" /mnt/boot
}

# Merge NFS mount from existing hardware into new hardware
merge_nfs_mount() {
  local old_hw="$1" new_hw="$2"
  # If old has an explicit fileSystems."/mnt/nas" attr, extract and inject
  if [ -f "$old_hw" ] && grep -q 'fileSystems\."/mnt/nas"' "$old_hw"; then
    # Extract the block for fileSystems."/mnt/nas" = { ... };
    local tmpblk
    tmpblk=$(mktemp)
    awk '/fileSystems\."\/mnt\/nas"[[:space:]]*=/ {flag=1} flag{print} /};[[:space:]]*$/ && flag{flag=0}' "$old_hw" >"$tmpblk"
    if [ -s "$tmpblk" ]; then
      # Insert into the new fileSystems set before its closing "};" of that attrset
      # Find start and end lines of fileSystems attrset in new_hw
      local start end
      start=$(awk '/fileSystems[[:space:]]*=[[:space:]]*\{/{print NR; exit}' "$new_hw" || true)
      end=$(awk -v s="$start" 'NR>=s{ if($0 ~ /^\}[[:space:]]*;[[:space:]]*$/){print NR; exit}}' "$new_hw" || true)
      if [ -n "$start" ] && [ -n "$end" ]; then
        local pre post
        pre=$(mktemp); post=$(mktemp)
        sed -n "1,$((end-1))p" "$new_hw" >"$pre"
        sed -n "$end,\$p" "$new_hw" >"$post"
        {
          cat "$pre"
          echo "  # Preserved from previous hardware.nix"
          sed 's/^/  /' "$tmpblk"
          cat "$post"
        } >"$new_hw.tmp"
        mv "$new_hw.tmp" "$new_hw"
        rm -f "$pre" "$post"
      fi
    fi
    rm -f "$tmpblk"
  fi
}

# Begin flow
echo "=== ddubsOS Installer (flake) ==="

HOSTNAME=$(read_default "Hostname" "nixos")
USERNAME=$(read_default "Username" "dwilliams")

# Filesystem selection
echo
echo "Select filesystem:"
echo "  1) Btrfs (single disk)"
echo "  2) ext4  (single disk)"
echo "  3) XFS   (single disk)"
read -r -p "Choice [1-3]: " FS_CHOICE
case "${FS_CHOICE:-1}" in
  1) FS="btrfs" ;;
  2) FS="ext4" ;;
  3) FS="xfs" ;;
  *) echo "Invalid choice" >&2; exit 1 ;;
esac

# Disk confirm
DISK=$(select_disk)
echo
echo "WARNING: This will destroy ALL data on $DISK"
read -r -p "Type 'INSTALL' to proceed: " ok
[ "$ok" = "INSTALL" ] || { echo "Aborted"; exit 1; }

# Ensure the selected disk (and its partitions) are not mounted
if any_mounts_under "$DISK"; then
  echo "Device appears mounted (or has mounted partitions). Unmount first." >&2
  lsblk -n -o NAME,MOUNTPOINTS "$DISK" >&2 || true
  exit 1
fi

# Prep per filesystem
case "$FS" in
  btrfs) prep_btrfs "$DISK" ;;
  ext4)  prep_ext4  "$DISK" ;;
  xfs)   prep_xfs   "$DISK" ;;
  *) echo "Unsupported FS: $FS" >&2; exit 1 ;;
esac

# Generate hardware config
nixos-generate-config --root /mnt

# Stage ddubsos flake under target
mkdir -p /mnt/etc/nixos
if [ -d "$DDUBS_LOCAL/.git" ] || [ -f "$DDUBS_LOCAL/flake.nix" ]; then
  echo "Copying local ddubsos from $DDUBS_LOCAL ..."
  rm -rf "$DDUBS_TARGET_ROOT"
  mkdir -p "$DDUBS_TARGET_ROOT"
  # Use rsync if available for speed/excludes; fallback to cp -a
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$DDUBS_LOCAL/" "$DDUBS_TARGET_ROOT/"
  else
    cp -a "$DDUBS_LOCAL"/. "$DDUBS_TARGET_ROOT/"
  fi
else
  req git
  echo "Local ddubsos not found; cloning from GitLab ..."
  rm -rf "$DDUBS_TARGET_ROOT"
  git clone --depth 1 https://gitlab.com/dwilliam62/ddubsos "$DDUBS_TARGET_ROOT"
fi

# Ensure host folder exists in staged repo
HOST_DIR="$DDUBS_TARGET_ROOT/hosts/$HOSTNAME"
if [ ! -d "$HOST_DIR" ]; then
  echo "Creating host '$HOSTNAME' from default template ..."
  mkdir -p "$DDUBS_TARGET_ROOT/hosts"
  cp -a "$DDUBS_TARGET_ROOT/hosts/default" "$HOST_DIR"
fi

# Write/merge hardware.nix for host
if [ ! -f "$LIVE_HWCFG" ]; then
  echo "Generated $LIVE_HWCFG not found" >&2; exit 1
fi
cp "$LIVE_HWCFG" "$HOST_DIR/hardware.nix"
# Preserve /mnt/nas from existing local repo (if present)
if [ -f "$DDUBS_LOCAL/hosts/$HOSTNAME/hardware.nix" ]; then
  merge_nfs_mount "$DDUBS_LOCAL/hosts/$HOSTNAME/hardware.nix" "$HOST_DIR/hardware.nix"
fi

# Update username in the staged flake (specialArgs default)
FLAKE_FILE="$DDUBS_TARGET_ROOT/flake.nix"
if [ -f "$FLAKE_FILE" ]; then
  # Replace the top-level default username = "..."; keeping formatting tolerant
  sed -i -E "s/^([[:space:]]*username[[:space:]]*=[[:space:]]*")([^"]+)("[[:space:]]*;)/\1$USERNAME\3/" "$FLAKE_FILE" || true
fi

# Set hostname in NixOS hardware or leave to flake modules; ddubsos modules set networking settings elsewhere

# Run installation using the staged flake
echo
echo "Starting installation from ddubsos flake for host '$HOSTNAME' ..."
# Pass accept-flake-config to avoid prompts in environments without matching nix.conf
nixos-install --flake "$DDUBS_TARGET_ROOT#$HOSTNAME" --option accept-flake-config true

echo
echo "Installation complete. You can reboot into the installed system."
