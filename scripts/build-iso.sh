#!/usr/bin/env bash
# Wrapper to build ISO images with the expected environment variables and flags.
# Repository (fork): https://github.com/dwilliam62/nix-iso
# Upstream inspiration: https://github.com/JohnRTitor/nix-iso
#
# Usage:
#   ./scripts/build-iso.sh [PROFILE]
# Where PROFILE is one of: nixos-minimal, nixos-gnome, nixos-cosmic
# Default PROFILE: nixos-minimal
#
# All profiles include the recovery toolset by default.

set -euo pipefail

PROFILE=${1:-nixos-minimal}
case "$PROFILE" in
  nixos-minimal|nixos-gnome|nixos-cosmic) ;;
  *) echo "Unknown PROFILE: $PROFILE" >&2; exit 2;;
 esac

# Allow broken packages by default to match historical behavior
export NIXPKGS_ALLOW_BROKEN="${NIXPKGS_ALLOW_BROKEN:-1}"

echo "==> Building profile: $PROFILE"
echo "==> NIXPKGS_ALLOW_BROKEN=$NIXPKGS_ALLOW_BROKEN"
echo "==> Fork repo: https://github.com/dwilliam62/nix-iso"
echo "==> Upstream credits: https://github.com/JohnRTitor/nix-iso"

echo "==> Running: nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure"
nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure

echo "==> Done. ISO should be in ./result/iso/"
