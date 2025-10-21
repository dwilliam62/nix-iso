<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./quickstart-btrfs.md) | Español

# Guía rápida: instalador Btrfs

Usa esto cuando instales NixOS en un solo disco con Btrfs.

Prerrequisitos
- Firmware UEFI (se usa systemd-boot)
- Ejecutar como root (sudo está bien)
- Sin sistemas de archivos Btrfs montados

Pasos
1) Ejecutar el instalador
```bash
./scripts/install-btrfs.sh
```
2) Seguir las indicaciones
- Zona horaria, mapa de teclado, nombre de host, nombre de usuario (y contraseña si OpenSSL está disponible)
- Selecciona el disco de destino
- Confirma la acción destructiva escribiendo INSTALL
3) Lo que hace el script
- Particiona el disco: 1 GiB ESP (FAT32), resto Btrfs
- Crea subvolúmenes: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots
- Monta con compress=zstd,discard=async,noatime
- Monta la ESP en /mnt/boot
- Genera hardware config y escribe configuration.nix
- Ejecuta nixos-install
4) Reinicia en tu nuevo sistema

Barandillas
- Se niega si hay sistemas de archivos Btrfs montados
- Advierte en entornos contenedorizados y cuando faltan efivars UEFI

