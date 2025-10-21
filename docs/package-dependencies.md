<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./package-dependencies.es.md)

# Package dependencies

This document lists the required packages/tools for:
- Building the ISO images (host build prerequisites)
- Running the interactive installers (per-filesystem, when used outside our live ISO)

If you use our live ISO, these tools are already included (see Tools-Included.md). This list is useful if you want to run the installers from another NixOS live environment or a different distro.

Build prerequisites (host)
- Nix with flakes enabled
- Git
- Optional (highly recommended): Configure binary caches (nix-community, chaotic nyx)

Common runtime dependencies (all installers)
- Shell and core utilities
  - bash, coreutils, util-linux (lsblk, mount, blockdev, wipefs), grep, sed, awk, tee, findutils
- Partitioning and EFI
  - parted (GPT partitioning)
  - dosfstools (mkfs.fat) for the ESP
  - efibootmgr (optional; systemd-boot may write efivars directly if available)
- NixOS installer tools (when running from NixOS live environment)
  - nixos-generate-config, nixos-install
- Misc helpers used by mirrored installers
  - blkid, blockdev, wipefs

Filesystem-specific runtime dependencies
- Btrfs installers (scripts/install-btrfs.sh, scripts/install-btrfs-boot-mirror.sh)
  - btrfs-progs (mkfs.btrfs, btrfs)
- ZFS installers (scripts/install-zfs.sh, scripts/install-zfs-boot-mirror.sh)
  - zpool, zfs userland matching the running kernel/module
  - ZFS kernel module must be available (lsmod/modprobe)
- bcachefs installer (scripts/install-bcachefs.sh)
  - bcachefs-tools (mkfs.bcachefs, bcachefs)
  - bcachefs kernel support (built-in or module)
- ext4 installer (scripts/install-ext4.sh)
  - e2fsprogs (mkfs.ext4)
- XFS installer (scripts/install-xfs.sh)
  - xfsprogs (mkfs.xfs)

Included on our live ISOs (for convenience)
- Tools-Included.md lists the complete live ISO toolset. Highlights:
  - parted, gptfdisk (sgdisk), efibootmgr
  - dosfstools (mkfs.fat)
  - btrfs-progs, e2fsprogs, xfsprogs, bcachefs-tools
  - ZFS userland (zpool, zfs) via config.boot.zfs.package
  - util-linux, coreutils, gnused, gawk, gnugrep, findutils, ripgrep
  - nixos-generate-config, nixos-install

Notes
- On some systems, parted and other admin tools live in /usr/sbin or /sbin. Our installers add common sbin paths to PATH, but if you run the scripts directly on another distro, ensure your PATH includes sbin directories.
- ZFS and bcachefs require compatible kernel support in the environment where you run the installer.

