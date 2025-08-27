<!--
Autor: Don Williams (aka ddubs)
Creado: 2025-08-27
Proyecto: https://github.com/dwilliam62/nix-iso
-->

[English](./Tools-Included.md) | Español

# Conjunto de herramientas del ISO en vivo (incluido en todos los perfiles)

Este documento lista las herramientas incluidas en todos los perfiles de ISO (minimal, GNOME, COSMIC), agrupadas por categoría.

CLI básico
- coreutils (cat, ls, etc.)
- util-linux, busybox
- gnused, gawk, gnugrep, findutils, ripgrep, ugrep
- which, file

Editores
- neovim, vim, nano

Red/Transferencia/Diagnóstico
- openssh, curl, wget, rsync
- iproute2 (ip), iputils (ping), mtr, traceroute, nmap
- socat, netcat-openbsd
- jq, yq-go

Almacenamiento / Sistemas de archivos
- parted, gptfdisk (sgdisk), efibootmgr
- btrfs-progs, e2fsprogs, xfsprogs
- bcachefs-tools
- ntfs3g, exfatprogs, dosfstools (mkfs.fat)
- nfs-utils, cifs-utils (montajes NFS/SMB)
- Herramientas userland de ZFS vía boot.zfs.package (zpool, zfs)
- cryptsetup, lvm2, mdadm

Recuperación / Imagen / Archivado
- ddrescue, testdisk
- zstd, xz, bzip2, gzip, zip, unzip, pv

Hardware / Depuración / Inspección
- pciutils (lspci), usbutils (lsusb)
- smartmontools (smartctl), hdparm, nvme-cli
- lshw, lsof, strace, gdb

Herramientas de snapshot y backup para Btrfs
- snapper
- btrbk

Notas
- Los ISOs en vivo empaquetan scripts/ en $PATH (p. ej., install-btrfs.sh).
- El ISO en vivo habilita sshd con autenticación por contraseña por conveniencia (cámbialo tras la instalación).
- sudo está disponible en el ISO en vivo; el usuario por defecto tiene sudo sin contraseña.
- La documentación está disponible en /etc/ddubsos-docs.
- El conjunto de herramientas de recuperación está incluido por defecto en todos los perfiles; el perfil de recuperación dedicado se mantiene por compatibilidad pero reutiliza el mismo módulo.

