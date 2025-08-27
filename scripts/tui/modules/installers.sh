#!/usr/bin/env bash
# Register installer menu and items
# Sections: Install scripts; Items: bcachefs (EXPERIMENTAL), zfs, zfs mirror (Testing), btrfs, btrfs mirror (Testing)

# Register section
register_section installers "Install scripts"

# Helper to safely register an installer if present in PATH
_add_installer_item() {
  local id="$1" label="$2" cmd="$3" warn_text="${4:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    register_item installers "$id" "$label" "$cmd" "$warn_text"
  else
    # Still register; the script will fail gracefully with command-not-found
    register_item installers "$id" "$label" "$cmd" "$warn_text"
  fi
}

# Group: Standard installers
register_header installers "Standard installers"
_add_installer_item \
  btrfs \
  "Install NixOS on Btrfs" \
  "install-btrfs.sh"
_add_installer_item \
  xfs \
  "Install NixOS on XFS" \
  "install-xfs.sh"
_add_installer_item \
  ext4 \
  "Install NixOS on ext4" \
  "install-ext4.sh"
_add_installer_item \
  zfs \
  "Install NixOS on ZFS" \
  "install-zfs.sh"

# Group: Experimental
register_header installers "Experimental"
_add_installer_item \
  bcachefs \
  "Install NixOS on Bcachefs" \
  "install-bcachefs.sh" \
  "EXPERIMENTAL - Use at own risk"

# Group: Mirror installers (Testing)
register_header installers "Mirror installers (Testing - not for production use)"
_add_installer_item \
  zfs_mirror \
  "Install NixOS on ZFS Mirror" \
  "install-zfs-boot-mirror.sh" \
  "Testing - not for production use"
_add_installer_item \
  btrfs_mirror \
  "Install NixOS on Btrfs Mirror" \
  "install-btrfs-boot-mirror.sh" \
  "Testing - not for production use"

