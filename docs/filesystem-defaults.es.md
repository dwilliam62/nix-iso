[English](./filesystem-defaults.md) | Español

# Valores predeterminados del instalador de sistemas de archivos

Este documento resume los parámetros y ajustes predeterminados que usan los scripts de instalación interactivos en scripts/ para cada sistema de archivos compatible.

Notas
- Modelo de particionado (todos los instaladores): GPT con una partición del sistema EFI (FAT32) de 1 GiB y el resto asignado al sistema de archivos o pool seleccionado.
- Entrada del usuario: zona horaria, mapa de teclado, nombre de host, nombre de usuario (con hash de contraseña opcional vía openssl).
- Gestor de arranque: systemd-boot en UEFI; se usa mirroredBoots cuando hay dos ESP montadas en /boot y /boot2.
- zswap: habilitado vía kernelParams (z3fold, zstd) para amplia compatibilidad.
- Barandillas de seguridad: los instaladores avisan si se ejecutan en contenedores, anotan la ausencia de efivars UEFI y se niegan a continuar si hay montajes en conflicto (por sistema de archivos).

## Btrfs
- mkfs
  - Disco único: mkfs.btrfs -f -L nixos $P2
  - Raíz en espejo: mkfs.btrfs -f -L nixos -m raid1 -d raid1 $P2A $P2B
- Subvolúmenes
  - @ (root), @home, @nix, @snapshots
- Opciones de montaje
  - compress=zstd, discard=async, noatime
- Diseño de montaje
  - subvol=@ → /
  - subvol=@home → /home
  - subvol=@nix → /nix
  - subvol=@snapshots → /.snapshots
- Arranque en espejo (opcional)
  - Dos ESP montadas en /boot y /boot2
  - boot.loader.systemd-boot.mirroredBoots configurado para replicar a /boot2
- Barandillas
  - Se niega a ejecutarse si hay sistemas de archivos btrfs montados
- Pistas de configuración de NixOS
  - Btrfs funciona de fábrica; herramientas incluidas: btrfs-progs

Ejemplo
```sh
mkfs.btrfs -f -L nixos "$P2"
mount -o compress=zstd,discard=async,noatime,subvol=@ "$P2" /mnt
mount -o compress=zstd,discard=async,noatime,subvol=@home "$P2" /mnt/home
mount -o compress=zstd,discard=async,noatime,subvol=@nix "$P2" /mnt/nix
mount -o compress=zstd,discard=async,noatime,subvol=@snapshots "$P2" /mnt/.snapshots
```

## ext4
- mkfs
  - mkfs.ext4 -F -L nixos $P2
- Opciones de montaje
  - noatime
- Configuración de NixOS
```nix
services.fstrim.enable = true;
```

Ejemplo
```sh
mkfs.ext4 -F -L nixos "$P2"
mount -o noatime "$P2" /mnt
```

## XFS
- mkfs
  - mkfs.xfs -f -L nixos $P2
- Opciones de montaje
  - noatime
- Configuración de NixOS
```nix
services.fstrim.enable = true;
```

Ejemplo
```sh
mkfs.xfs -f -L nixos "$P2"
mount -o noatime "$P2" /mnt
```

## bcachefs (experimental)
- mkfs
  - mkfs.bcachefs -f --compression=zstd -L nixos $P2
- Subvolúmenes
  - @ (root), @home, @nix, @var, @var_log, @var_cache, @var_tmp, @var_lib
- Opciones de montaje
  - compress=zstd, noatime
- Barandillas
  - Requiere reconocimiento explícito de EXPERIMENT
  - Verifica soporte del kernel (modprobe / /proc/filesystems)
  - Se niega a ejecutarse si hay bcachefs montado
- Configuración de NixOS
```nix
boot.supportedFilesystems = [ "bcachefs" ];
boot.initrd.supportedFilesystems = [ "bcachefs" ];
services.fstrim.enable = true;
```

Ejemplo
```sh
mkfs.bcachefs -f --compression=zstd -L nixos "$P2"
mount -o compress=zstd,noatime,subvol=/@ "/dev/disk/by-uuid/$FSUUID" /mnt
```

## ZFS
- Particionado y EFI
  - ESP: FAT32, 1 GiB
  - Pool: usa el espacio restante
- Creación del pool (predeterminados)
```sh
zpool create -f \
  -o ashift=12 \
  -o autotrim=on \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  -R /mnt \
  "$POOL" "$P2"
```
- Datasets (puntos de montaje legacy)
  - $POOL/root (mountpoint=none); $POOL/root/nixos → /
  - $POOL/home → /home
  - $POOL/nix → /nix (atime=off)
  - $POOL/var (mountpoint=none);
    - $POOL/var/log → /var/log (exec=off, devices=off)
    - $POOL/var/cache → /var/cache (exec=off, devices=off, com.sun:auto-snapshot=false)
    - $POOL/var/tmp → /var/tmp (exec=off, devices=off, com.sun:auto-snapshot=false)
    - $POOL/var/lib → /var/lib
- Arranque en espejo (opcional)
  - Dos ESP montadas en /boot y /boot2; boot.loader.systemd-boot.mirroredBoots configurado
  - zpool en espejo (vdev mirror): zpool create ... mirror $P2A $P2B
- Barandillas
  - Verifica disponibilidad del módulo del kernel ZFS (lsmod/modprobe)
  - Se niega si hay sistemas de archivos ZFS montados o pools importados
- Configuración de NixOS
```nix
boot.supportedFilesystems = [ "zfs" ];
boot.initrd.supportedFilesystems = [ "zfs" ];
networking.hostId = "<generated-8-hex-digits>"; # requerido para import en initrd
services.zfs.autoScrub.enable = true;
services.fstrim.enable = true; # además de autotrim en el pool
```

Ejemplos de montajes
```sh
mount -t zfs "$POOL/root/nixos" /mnt
mount -t zfs "$POOL/home" /mnt/home
mount -t zfs "$POOL/nix" /mnt/nix
mount -t zfs "$POOL/var/log" /mnt/var/log
mount -t zfs "$POOL/var/cache" /mnt/var/cache
mount -t zfs "$POOL/var/tmp" /mnt/var/tmp
mount -t zfs "$POOL/var/lib" /mnt/var/lib
```

