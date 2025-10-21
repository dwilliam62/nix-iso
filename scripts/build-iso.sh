#!/usr/bin/env bash
# Wrapper to build ISO images with the expected environment variables and flags.
# Repository (fork): https://github.com/dwilliam62/nix-iso
# Upstream inspiration: https://github.com/JohnRTitor/nix-iso
#
# Usage:
#   ./scripts/build-iso.sh [PROFILE]
# PROFILE may be one of (or a friendly alias):
#   - nixos-minimal | minimal | min | mimimal (typo)
#   - nixos-gnome   | gnome
#   - nixos-cosmic  | cosmic
# Default PROFILE: nixos-minimal
#
# All profiles include the recovery toolset by default.

set -euo pipefail

RAW_INPUT=${1:-nixos-minimal}
INPUT=$(echo "$RAW_INPUT" | tr '[:upper:]' '[:lower:]')

case "$INPUT" in
  nixos-minimal|minimal|min|mimimal|minimal-iso)
    PROFILE="nixos-minimal";
    ;;
  nixos-gnome|gnome|gnoem|gome)
    PROFILE="nixos-gnome";
    ;;
  nixos-cosmic|cosmic|comsic|csmic)
    PROFILE="nixos-cosmic";
    ;;
  *)
    echo "Unknown PROFILE: $RAW_INPUT" >&2
    echo "Valid options: nixos-minimal | nixos-gnome | nixos-cosmic (aliases: minimal|min, gnome, cosmic)" >&2
    exit 2
    ;;
 esac

# Allow broken packages by default to match historical behavior
export NIXPKGS_ALLOW_BROKEN="${NIXPKGS_ALLOW_BROKEN:-1}"

echo "==> Building profile: $PROFILE (from input: $RAW_INPUT)"
echo "==> NIXPKGS_ALLOW_BROKEN=$NIXPKGS_ALLOW_BROKEN"
echo "==> Fork repo: https://github.com/dwilliam62/nix-iso"
echo "==> Upstream credits: https://github.com/JohnRTitor/nix-iso"

echo "==> Running: nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure"
nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure

echo "==> Done. ISO should be in ./result/iso/"
