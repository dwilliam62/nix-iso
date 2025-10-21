<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./filesystems-overview.es.md)

# NixOS installer reference: ZFS, Btrfs, and bcachefs

This guide complements the interactive installer scripts under scripts/.
It explains the layouts they create, mirrored boot setups, and safety guardrails.

Quick overview
- UEFI + systemd-boot is used for all installers.
- Partitioning: 1 GiB ESP (FAT32) + remainder for the filesystem/pool.
- zswap enabled via kernelParams (z3fold + zstd).
- Guardrails: environment warnings and checks to avoid accidental data loss.

ZFS
- Layout
  - rpool/root (mountpoint=none)
  - rpool/root/nixos → /
  - rpool/home → /home
  - rpool/nix → /nix (atime=off)
  - rpool/var (mountpoint=none)
    - rpool/var/log → /var/log (exec=off, devices=off)
    - rpool/var/cache → /var/cache (exec=off, devices=off, com.sun:auto-snapshot=false)
    - rpool/var/tmp → /var/tmp (exec=off, devices=off, com.sun:auto-snapshot=false)
    - rpool/var/lib → /var/lib
- Mirrored boot (optional)
  - Dual ESPs: /boot and /boot2
  - systemd-boot.mirroredBoots replicates bootloader to /boot2
  - Mirrored root: zpool create ... mirror disk2-part2 disk2-part2
- Guardrails
  - Verify ZFS kernel module (lsmod/modprobe)
  - Refuse if any ZFS filesystems are mounted or any pools are imported
  - UEFI note if efivars missing; container warning if inside container
- NixOS settings
  - boot.supportedFilesystems = [ "zfs" ];
  - boot.initrd.supportedFilesystems = [ "zfs" ];
  - networking.hostId set for initrd pool import

Btrfs
- Layout (single-disk installer)
  - Subvolumes: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots
- Mirrored boot option (separate installer)
  - RAID1 filesystem: mkfs.btrfs -m raid1 -d raid1 devA devB
  - Dual ESPs: /boot and /boot2 with systemd-boot.mirroredBoots
- Guardrails
  - Refuse if any btrfs filesystems are mounted
  - UEFI note if efivars missing; container warning

bcachefs (experimental)
- Layout
  - Subvolumes: @ → /, @home → /home, @nix → /nix, and split /var into
    @var, @var_log, @var_cache, @var_tmp, @var_lib
- Purpose
  - Experimental only; may be removed from mainline; use on disposable hardware/VMs
- Guardrails
  - Require explicit EXPERIMENT acknowledgement
  - Verify kernel support (modprobe and /proc/filesystems)
  - Refuse if any bcachefs is mounted; UEFI note; container warning
- NixOS settings
  - boot.supportedFilesystems and boot.initrd.supportedFilesystems include "bcachefs"

Appendix: common warnings
- Running inside containers can prevent access to block devices, modules, and efivars.
- Missing /sys/firmware/efi/efivars means systemd-boot may skip NVRAM writes.
- Always unmount other filesystems of the same type before running a destructive installer.

