#!/usr/bin/env bash
# Wrapper to build ISO images with the expected environment variables and flags.
# Usage:
#   ./scripts/build-iso.sh [PROFILE]
# Where PROFILE is one of: nixos-minimal, nixos-gnome, nixos-cosmic, nixos-recovery
# Default PROFILE: nixos-recovery

set -euo pipefail

PROFILE=${1:-nixos-recovery}
case "$PROFILE" in
  nixos-minimal|nixos-gnome|nixos-cosmic|nixos-recovery) ;;
  *) echo "Unknown PROFILE: $PROFILE" >&2; exit 2;;
esac

# Allow broken packages by default to match upstream README behavior
export NIXPKGS_ALLOW_BROKEN="${NIXPKGS_ALLOW_BROKEN:-1}"

echo "==> Building profile: $PROFILE"
echo "==> NIXPKGS_ALLOW_BROKEN=$NIXPKGS_ALLOW_BROKEN"

echo "==> Running: nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure"
nix build .#nixosConfigurations.${PROFILE}.config.system.build.isoImage --impure

echo "==> Done. ISO should be in ./result/iso/"
