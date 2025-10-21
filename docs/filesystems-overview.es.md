<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./filesystems-overview.md) | Español

# Referencia del instalador de NixOS: ZFS, Btrfs y bcachefs

Esta guía complementa los scripts de instalación interactivos en scripts/.
Explica los diseños que crean, las configuraciones de arranque en espejo y las barandillas de seguridad.

Resumen rápido
- UEFI + systemd-boot se usa para todos los instaladores.
- Particionado: ESP de 1 GiB (FAT32) + resto para el sistema de archivos/pool.
- zswap habilitado vía kernelParams (z3fold + zstd).
- Barandillas: advertencias de entorno y comprobaciones para evitar pérdida accidental de datos.

ZFS
- Diseño
  - rpool/root (mountpoint=none)
  - rpool/root/nixos → /
  - rpool/home → /home
  - rpool/nix → /nix (atime=off)
  - rpool/var (mountpoint=none)
    - rpool/var/log → /var/log (exec=off, devices=off)
    - rpool/var/cache → /var/cache (exec=off, devices=off, com.sun:auto-snapshot=false)
    - rpool/var/tmp → /var/tmp (exec=off, devices=off, com.sun:auto-snapshot=false)
    - rpool/var/lib → /var/lib
- Arranque en espejo (opcional)
  - Doble ESP: /boot y /boot2
  - systemd-boot.mirroredBoots replica el gestor de arranque a /boot2
  - Raíz en espejo: zpool create ... mirror disk2-part2 disk2-part2
- Barandillas
  - Verificar el módulo del kernel ZFS (lsmod/modprobe)
  - Negarse si cualquier sistema de archivos ZFS está montado o si hay pools importados
  - Nota UEFI si faltan efivars; advertencia si se está en contenedor
- Ajustes de NixOS
  - boot.supportedFilesystems = [ "zfs" ];
  - boot.initrd.supportedFilesystems = [ "zfs" ];
  - networking.hostId configurado para import del pool en initrd

Btrfs
- Diseño (instalador de un solo disco)
  - Subvolúmenes: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots
- Opción de arranque en espejo (instalador separado)
  - Sistema de archivos RAID1: mkfs.btrfs -m raid1 -d raid1 devA devB
  - Doble ESP: /boot y /boot2 con systemd-boot.mirroredBoots
- Barandillas
  - Negarse si hay sistemas de archivos btrfs montados
  - Nota UEFI si faltan efivars; advertencia de contenedor

bcachefs (experimental)
- Diseño
  - Subvolúmenes: @ → /, @home → /home, @nix → /nix, y dividir /var en
    @var, @var_log, @var_cache, @var_tmp, @var_lib
- Propósito
  - Solo experimental; puede ser eliminado del mainline; usar en hardware/VM desechables
- Barandillas
  - Requiere reconocimiento explícito de EXPERIMENT
  - Verifica soporte del kernel (modprobe y /proc/filesystems)
  - Negarse si hay bcachefs montado; nota UEFI; advertencia de contenedor
- Ajustes de NixOS
  - boot.supportedFilesystems y boot.initrd.supportedFilesystems incluyen "bcachefs"

Apéndice: advertencias comunes
- Ejecutarse dentro de contenedores puede impedir acceso a dispositivos de bloque, módulos y efivars.
- La ausencia de /sys/firmware/efi/efivars significa que systemd-boot puede omitir escrituras NVRAM.
- Desmonta siempre otros sistemas de archivos del mismo tipo antes de ejecutar un instalador destructivo.

