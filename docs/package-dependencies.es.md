<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./package-dependencies.md) | Español

# Dependencias de paquetes

Este documento enumera los paquetes/herramientas necesarios para:
- Construir las imágenes ISO (prerrequisitos en el host)
- Ejecutar los instaladores interactivos (por sistema de archivos, cuando se usan fuera de nuestro ISO en vivo)

Si usas nuestro ISO en vivo, estas herramientas ya están incluidas (consulta Tools-Included.md). Esta lista es útil si quieres ejecutar los instaladores desde otro entorno en vivo de NixOS o desde una distro diferente.

Prerrequisitos de compilación (host)
- Nix con flakes habilitadas
- Git
- Opcional (altamente recomendado): configurar cachés binarias (nix-community, chaotic nyx)

Dependencias de ejecución comunes (todos los instaladores)
- Shell y utilidades básicas
  - bash, coreutils, util-linux (lsblk, mount, blockdev, wipefs), grep, sed, awk, tee, findutils
- Particionado y EFI
  - parted (particionado GPT)
  - dosfstools (mkfs.fat) para la ESP
  - efibootmgr (opcional; systemd-boot puede escribir efivars directamente si están disponibles)
- Herramientas del instalador de NixOS (cuando se ejecuta desde un entorno en vivo de NixOS)
  - nixos-generate-config, nixos-install
- Miscelánea usada por los instaladores con espejo
  - blkid, blockdev, wipefs

Dependencias específicas por sistema de archivos
- Instaladores Btrfs (scripts/install-btrfs.sh, scripts/install-btrfs-boot-mirror.sh)
  - btrfs-progs (mkfs.btrfs, btrfs)
- Instaladores ZFS (scripts/install-zfs.sh, scripts/install-zfs-boot-mirror.sh)
  - zpool, zfs userland que corresponda al kernel/módulo en ejecución
  - El módulo del kernel ZFS debe estar disponible (lsmod/modprobe)
- Instalador bcachefs (scripts/install-bcachefs.sh)
  - bcachefs-tools (mkfs.bcachefs, bcachefs)
  - Soporte de kernel para bcachefs (integrado o como módulo)
- Instalador ext4 (scripts/install-ext4.sh)
  - e2fsprogs (mkfs.ext4)
- Instalador XFS (scripts/install-xfs.sh)
  - xfsprogs (mkfs.xfs)

Incluido en nuestros ISOs en vivo (por conveniencia)
- Tools-Included.md lista el conjunto completo de herramientas del ISO en vivo. Destacados:
  - parted, gptfdisk (sgdisk), efibootmgr
  - dosfstools (mkfs.fat)
  - btrfs-progs, e2fsprogs, xfsprogs, bcachefs-tools
  - ZFS userland (zpool, zfs) vía config.boot.zfs.package
  - util-linux, coreutils, gnused, gawk, gnugrep, findutils, ripgrep
  - nixos-generate-config, nixos-install

Notas
- En algunos sistemas, parted y otras herramientas de administración viven en /usr/sbin o /sbin. Nuestros instaladores añaden rutas sbin comunes al PATH, pero si ejecutas los scripts directamente en otra distro, asegúrate de que tu PATH incluya los directorios sbin.
- ZFS y bcachefs requieren soporte de kernel compatible en el entorno donde ejecutes el instalador.

