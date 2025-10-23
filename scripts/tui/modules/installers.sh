#!/usr/bin/env bash
# Author: Don Williams (aka ddubs)
# Created: 2025-10-21
# Project: https://github.com/dwilliam62/nix-iso
# Register installer menu and items
# Sections: Install scripts; Items: btrfs, xfs, ext4, btrfs mirror (Testing)

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
  ddubsos \
  "Install ddubsOS (select FS, disk; flake-based)" \
  "[ -x /home/dwilliams/Projects/ddubs/nix-iso/scripts/install-ddubsos.sh ] && /home/dwilliams/Projects/ddubs/nix-iso/scripts/install-ddubsos.sh || $SCRIPT_DIR/install-ddubsos.sh"
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

# Group: Mirror installers (Testing)
register_header installers "Mirror installers (Testing - not for production use)"
_add_installer_item \
  btrfs_mirror \
  "Install NixOS on Btrfs Mirror" \
  "install-btrfs-boot-mirror.sh" \
  "Testing - not for production use"
