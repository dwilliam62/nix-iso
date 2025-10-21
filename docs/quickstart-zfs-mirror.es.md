<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./quickstart-zfs-mirror.md) | Español

# Guía rápida: instalador ZFS con arranque en espejo

Usa esto cuando instales NixOS en dos discos con raíz ZFS en espejo y gestor de arranque en espejo.

Prerrequisitos
- Firmware UEFI (se usa systemd-boot con mirroredBoots)
- Ejecutar como root (sudo está bien)
- Módulo del kernel ZFS disponible
- Al menos dos discos completamente desmontados

Pasos
1) Ejecutar el instalador
```bash
./scripts/install-zfs-boot-mirror.sh
```
2) Seguir las indicaciones
- Zona horaria, mapa de teclado, nombre de host, nombre de usuario (y contraseña si OpenSSL está disponible)
- Selecciona dos discos de destino (los tamaños pueden diferir; el espejo usa el menor tamaño)
- Confirma la acción destructiva escribiendo INSTALL
3) Lo que hace el script
- Particiona ambos discos: 1 GiB ESP (FAT32), resto ZFS
- Crea un zpool en espejo (vdev mirror)
- Datasets y montajes iguales al ZFS de un solo disco
- Monta las ESP en /mnt/boot y /mnt/boot2
- Escribe configuration.nix con systemd-boot.mirroredBoots e initrd para ZFS
- Ejecuta nixos-install
4) Reinicia en tu nuevo sistema

Barandillas
- Se niega si hay sistemas de archivos ZFS montados o pools importados
- Verifica la disponibilidad del módulo ZFS
- Advierte en entornos contenedorizados y cuando faltan efivars UEFI

