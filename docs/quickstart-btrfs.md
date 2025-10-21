<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./quickstart-btrfs.es.md)

# Quickstart: Btrfs installer

Use this when installing NixOS on a single disk with Btrfs.

Prerequisites
- UEFI firmware (systemd-boot is used)
- Running as root (sudo is fine)
- No Btrfs filesystems mounted

Steps
1) Run the installer
```bash
./scripts/install-btrfs.sh
```
2) Follow prompts
- Timezone, keymap, hostname, username (and password if OpenSSL is available)
- Select the target disk
- Confirm destructive action by typing INSTALL
3) What the script does
- Partitions the disk: 1 GiB ESP (FAT32), rest Btrfs
- Creates subvolumes: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots
- Mounts with compress=zstd,discard=async,noatime
- Mounts ESP at /mnt/boot
- Generates hardware config and writes configuration.nix
- Runs nixos-install
4) Reboot into your new system

Guardrails
- Refuses if any Btrfs filesystems are mounted
- Warns on containerized environments and missing UEFI efivars

