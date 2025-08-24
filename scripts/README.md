# install-btrfs.sh usage

This script performs an interactive, opinionated Btrfs-based NixOS installation.
It is designed to be run from the recovery ISO environment.

What it does
- Prompts for timezone, console keymap, hostname, and username
- Lets you select the target disk from detected devices
- Confirms with a mandatory "INSTALL" to avoid accidents
- Partitions the target as:
  - 1 GiB EFI System Partition (vfat)
  - Remaining space as Btrfs
- Creates Btrfs subvolumes: @ (root), @home, @nix, @snapshots
- Mounts with: compress=zstd, discard=async, noatime
- Generates hardware-configuration.nix
- Writes /etc/nixos/configuration.nix from a safe template:
  - zswap via kernelParams (z3fold)
  - NetworkManager enabled
  - sudo wheel members require password (wheelNeedsPassword = true)
  - unfree allowed; flakes enabled
- Runs nixos-install (you will be prompted to set the root password)

How to run
- Run as root. The script will self-elevate via sudo if available, otherwise exit with instructions.
```
./install-btrfs.sh
```

Docs on the live ISO
- Find docs under /etc/ddubsos-docs (README.md, HOWTO.md, Tools-Included.md, and docs/*).

Notes
- The script will destroy data on the selected disk. Read prompts carefully.
- Subvolume layout includes /.snapshots for tools like snapper.
- The script template does not set any user passwords; root password is set interactively by nixos-install.
- After booting into the installed system, you can add snapper/btrbk/grub-btrfs configuration if desired.

