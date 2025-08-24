# Tools Included on the Recovery ISO

This document lists the tooling included on the nixos-recovery ISO profile, grouped by category.

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
- cryptsetup, lvm2, mdadm

Recovery / Imaging / Archiving
- gddrescue, testdisk
- zstd, xz, bzip2, gzip, zip, unzip, pv

Hardware / Debug / Inspection
- pciutils (lspci), usbutils (lsusb)
- smartmontools (smartctl), hdparm, nvme-cli
- lshw, lsof, strace, gdb

Btrfs Snapshot & Backup Tooling
- snapper
- btrbk
- grub-btrfs
- btrfsmaintenance

Notes
- The recovery ISO also packages scripts/ into $PATH (e.g. install-btrfs.sh).
- The live ISO enables sshd with password auth for convenience (change after install).
- Base ISO profiles (minimal/gnome/cosmic) inherit baseline tools from common.nix, but the recovery profile is the superset intended for install and rescue workflows.
