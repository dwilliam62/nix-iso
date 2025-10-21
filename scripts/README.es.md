<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./README.md) | Español

# Scripts de instalación de sistemas de archivos

Estos scripts realizan instalaciones interactivas y con criterios definidos de NixOS para múltiples sistemas de archivos. Están diseñados para ejecutarse desde el ISO en vivo o cualquier entorno que tenga disponibles las herramientas necesarias.

Flujo común en todos los instaladores
- Solicita zona horaria, mapa de teclado de consola, nombre de host y nombre de usuario (con hash seguro de contraseña si está presente openssl)
- Permite seleccionar el disco de destino entre los dispositivos detectados
- Confirma con un "INSTALL" obligatorio para evitar accidentes
- Particiona el destino como:
  - Partición del sistema EFI de 1 GiB (vfat)
  - El espacio restante como el sistema de archivos seleccionado
- Genera hardware-configuration.nix
- Escribe /etc/nixos/configuration.nix a partir de una plantilla segura:
  - Arranque UEFI con systemd-boot
  - zswap vía kernelParams (z3fold)
  - NetworkManager habilitado
  - Los miembros de wheel requieren contraseña para sudo (wheelNeedsPassword = true)
  - unfree permitido; flakes habilitadas
- Ejecuta nixos-install (se te pedirá establecer la contraseña de root)

Instaladores disponibles
- install-btrfs.sh
  - Sistema de archivos: Btrfs
  - Diseño: subvolúmenes @ (root), @home, @nix, @snapshots
  - Opciones de montaje: compress=zstd, discard=async, noatime
  - Notas: incluye /.snapshots para herramientas como snapper

- install-ext4.sh
  - Sistema de archivos: ext4
  - Opciones de montaje: noatime
  - Notas: ext4 no tiene compresión transparente nativa; habilita el timer de fstrim en la configuración

- install-xfs.sh
  - Sistema de archivos: XFS
  - Opciones de montaje: noatime
  - Notas: XFS no tiene compresión transparente nativa; habilita el timer de fstrim en la configuración

- install-bcachefs.sh
  - Sistema de archivos: bcachefs
  - Opciones de mkfs: --compression=zstd
  - Opciones de montaje: noatime
  - Configuración: boot.supportedFilesystems = [ "bcachefs" ]

- install-zfs.sh
  - Sistema de archivos: ZFS (pool de un solo disco por defecto)
  - Opciones de zpool create: ashift=12, autotrim=on, compression=zstd, atime=off, xattr=sa, acltype=posixacl, mountpoint=none, -R /mnt
  - Datasets: rpool/root, rpool/home, rpool/nix, rpool/snapshots (puntos de montaje legacy)
  - Configuración: boot.supportedFilesystems = [ "zfs" ], se genera un networking.hostId único para import en initrd
  - Servicios: services.zfs.autoScrub.enable = true

Cómo ejecutarlos
- Ejecuta como root. Los scripts se autoelevan vía sudo si es posible.

Ejemplos
```
# Btrfs
sudo ./install-btrfs.sh

# ext4
sudo ./install-ext4.sh

# XFS
sudo ./install-xfs.sh

# bcachefs
sudo ./install-bcachefs.sh

# ZFS
sudo ./install-zfs.sh
```

Documentación en el ISO en vivo
- Encuentra la documentación en /etc/ddubsos-docs (README.md, HOWTO.md, Tools-Included.md y docs/*).

Notas
- Estos scripts destruyen los datos del disco seleccionado. Lee las indicaciones con atención.
- La contraseña de root se establece de forma interactiva con nixos-install; la contraseña del usuario se hashea y escribe cuando es posible.
- Para ZFS, el diseño de datasets puede personalizarse (p. ej., datasets separados para /var, /var/log). Ajusta el script o configura tras la instalación.
- Para ext4/XFS, no hay compresión disponible; fstrim se habilita vía configuración.

