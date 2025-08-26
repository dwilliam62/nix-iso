English | [Español](./quickstart-zfs-mirror.es.md)

# Quickstart: ZFS mirrored boot installer

Use this when installing NixOS on two disks with a mirrored ZFS root and mirrored bootloader.

Prerequisites
- UEFI firmware (systemd-boot is used with mirroredBoots)
- Running as root (sudo is fine)
- ZFS kernel module available
- At least two completely unmounted disks

Steps
1) Run the installer
```bash
./scripts/install-zfs-boot-mirror.sh
```
2) Follow prompts
- Timezone, keymap, hostname, username (and password if OpenSSL is available)
- Select two target disks (sizes may differ; mirror uses the smaller size)
- Confirm destructive action by typing INSTALL
3) What the script does
- Partitions both disks: 1 GiB ESP (FAT32), rest ZFS
- Creates a mirrored zpool (mirror vdev)
- Datasets and mounts same as single-disk ZFS
- Mounts ESPs at /mnt/boot and /mnt/boot2
- Writes configuration.nix with systemd-boot.mirroredBoots and ZFS initrd
- Runs nixos-install
4) Reboot into your new system

Guardrails
- Refuses if any ZFS filesystems are mounted or pools imported
- Verifies ZFS module availability
- Warns on containerized environments and missing UEFI efivars

