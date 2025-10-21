<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./quickstart-btrfs-mirror.md) | Español

# Guía rápida: instalador Btrfs con arranque en espejo

Usa esto cuando instales NixOS en dos discos con raíz Btrfs en espejo y gestor de arranque en espejo.

Prerrequisitos
- Firmware UEFI (se usa systemd-boot con mirroredBoots)
- Ejecutar como root (sudo está bien)
- Dos discos completamente desmontados

Pasos
1) Ejecutar el instalador
```bash
./scripts/install-btrfs-boot-mirror.sh
```
2) Seguir las indicaciones
- Zona horaria, mapa de teclado, nombre de host, nombre de usuario (y contraseña si OpenSSL está disponible)
- Selecciona dos discos de destino (los tamaños pueden diferir; RAID1 usa el menor tamaño)
- Confirma la acción destructiva escribiendo INSTALL
3) Lo que hace el script
- Particiona ambos discos: 1 GiB ESP (FAT32), resto Btrfs
- Crea un sistema de archivos Btrfs en RAID1 (-m raid1 -d raid1)
- Crea subvolúmenes: @, @home, @nix, @snapshots
- Monta las ESP en /mnt/boot y /mnt/boot2
- Escribe configuration.nix con systemd-boot.mirroredBoots
- Ejecuta nixos-install
4) Reinicia en tu nuevo sistema

Barandillas
- Se niega si hay sistemas de archivos Btrfs montados
- Advierte en entornos contenedorizados y cuando faltan efivars UEFI

