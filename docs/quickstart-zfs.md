<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./quickstart-zfs.es.md)

# Quickstart: ZFS installer

Use this when installing NixOS on a single disk with ZFS root.

Prerequisites
- UEFI firmware (systemd-boot is used)
- Running as root (sudo is fine)
- ZFS kernel module available in the live environment
- No ZFS pools imported or ZFS filesystems mounted

Steps
1) Run the installer
```bash
./scripts/install-zfs.sh
```
2) Follow prompts
- Timezone, keymap, hostname, username (and password if OpenSSL is available)
- Select the target disk
- Confirm destructive action by typing INSTALL
3) What the script does
- Partitions the disk: 1 GiB ESP (FAT32), rest ZFS
- Creates a pool with safe defaults and datasets:
  - rpool/root (container), rpool/root/nixos → /
  - rpool/home → /home; rpool/nix → /nix
  - rpool/var (container): var/log, var/cache, var/tmp, var/lib
- Mounts datasets with legacy mountpoints, mounts ESP at /mnt/boot
- Generates hardware config and writes configuration.nix with ZFS settings
- Runs nixos-install
4) Reboot into your new system

Guardrails
- Refuses to run if any ZFS filesystems are mounted or if any pools are imported
- Verifies ZFS module availability (lsmod/modprobe)
- Warns when running inside containers or when UEFI efivars are missing

