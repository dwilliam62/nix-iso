<!--
Author: Don Williams (aka ddubs)
Created: 2025-08-27
Project: https://github.com/dwilliam62/nix-iso
-->

English | [Español](./Tools-Included.es.md)

# Live ISO Toolset (included in all profiles)

This document lists the tooling included on all ISO profiles (minimal, GNOME, COSMIC), grouped by category.

Core CLI
- coreutils (cat, ls, etc.)
- util-linux, busybox
- gnused, gawk, gnugrep, findutils, ripgrep, ugrep
- which, file

Editors
- neovim, vim, nano

Networking / Transfer / Diagnostics
- openssh, curl, wget, rsync
- iproute2 (ip), iputils (ping), mtr, traceroute, nmap
- socat, netcat-openbsd
- jq, yq-go

Storage / Filesystems
- parted, gptfdisk (sgdisk), efibootmgr
- btrfs-progs, e2fsprogs, xfsprogs
- bcachefs-tools
- ntfs3g, exfatprogs, dosfstools (mkfs.fat)
- nfs-utils, cifs-utils (NFS/SMB mounts)
- ZFS userland via boot.zfs.package (zpool, zfs)
- cryptsetup, lvm2, mdadm

Recovery / Imaging / Archiving
- ddrescue, testdisk
- zstd, xz, bzip2, gzip, zip, unzip, pv

Hardware / Debug / Inspection
- pciutils (lspci), usbutils (lsusb)
- smartmontools (smartctl), hdparm, nvme-cli
- lshw, lsof, strace, gdb

Btrfs Snapshot & Backup Tooling
- snapper
- btrbk

Notes
- The live ISOs package scripts/ into $PATH (e.g. install-btrfs.sh).
- The live ISO enables sshd with password auth for convenience (change after install).
- sudo is available on the live ISO; the default user has passwordless sudo.
- Docs are available under /etc/ddubsos-docs.
- The recovery toolset is included by default in all profiles; the dedicated recovery profile is maintained for compatibility but reuses the same module.
