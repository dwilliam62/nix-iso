<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./quickstart-btrfs-mirror.es.md)

# Quickstart: Btrfs mirrored boot installer

Use this when installing NixOS on two disks with a mirrored Btrfs root and mirrored bootloader.

Prerequisites
- UEFI firmware (systemd-boot is used with mirroredBoots)
- Running as root (sudo is fine)
- Two completely unmounted disks

Steps
1) Run the installer
```bash
./scripts/install-btrfs-boot-mirror.sh
```
2) Follow prompts
- Timezone, keymap, hostname, username (and password if OpenSSL is available)
- Select two target disks (sizes may differ; RAID1 uses the smaller size)
- Confirm destructive action by typing INSTALL
3) What the script does
- Partitions both disks: 1 GiB ESP (FAT32), rest Btrfs
- Creates a Btrfs filesystem in RAID1 (-m raid1 -d raid1)
- Creates subvolumes: @, @home, @nix, @snapshots
- Mounts ESPs at /mnt/boot and /mnt/boot2
- Writes configuration.nix with systemd-boot.mirroredBoots
- Runs nixos-install
4) Reboot into your new system

Guardrails
- Refuses if any Btrfs filesystems are mounted
- Warns on containerized environments and missing UEFI efivars

