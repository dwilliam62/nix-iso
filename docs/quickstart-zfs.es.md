[English](./quickstart-zfs.md) | Español

# Guía rápida: instalador ZFS

Usa esto cuando instales NixOS en un solo disco con raíz ZFS.

Prerrequisitos
- Firmware UEFI (se usa systemd-boot)
- Ejecutar como root (sudo está bien)
- Módulo del kernel ZFS disponible en el entorno en vivo
- Sin pools ZFS importados ni sistemas de archivos ZFS montados

Pasos
1) Ejecutar el instalador
```bash
./scripts/install-zfs.sh
```
2) Seguir las indicaciones
- Zona horaria, mapa de teclado, nombre de host, nombre de usuario (y contraseña si OpenSSL está disponible)
- Selecciona el disco de destino
- Confirma la acción destructiva escribiendo INSTALL
3) Lo que hace el script
- Particiona el disco: 1 GiB ESP (FAT32), resto ZFS
- Crea un pool con valores seguros por defecto y datasets:
  - rpool/root (contenedor), rpool/root/nixos → /
  - rpool/home → /home; rpool/nix → /nix
  - rpool/var (contenedor): var/log, var/cache, var/tmp, var/lib
- Monta datasets con puntos de montaje legacy, monta la ESP en /mnt/boot
- Genera hardware config y escribe configuration.nix con ajustes de ZFS
- Ejecuta nixos-install
4) Reinicia en tu nuevo sistema

Barandillas
- Se niega a ejecutarse si hay sistemas de archivos ZFS montados o si hay pools importados
- Verifica la disponibilidad del módulo ZFS (lsmod/modprobe)
- Advierte cuando se ejecuta dentro de contenedores o cuando faltan efivars UEFI

