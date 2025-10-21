English | [Español](./filesystem-defaults.es.md)

# Filesystem installer defaults

This document summarizes the default parameters and settings used by the interactive installer scripts in scripts/ for each supported filesystem.

Notes
- Partitioning model (all installers): GPT with a 1 GiB EFI System Partition (FAT32) and the remainder allocated to the selected filesystem or pool.
- User input: timezone, keymap, hostname, username (with optional password hashing via openssl).
- Bootloader: systemd-boot on UEFI; mirroredBoots is used when two ESPs are mounted at /boot and /boot2.
- zswap: enabled via kernelParams (z3fold, zstd) for broad compatibility.
- Guardrails: installers warn if running in containers, note missing UEFI efivars, and refuse to proceed if conflicting mounts are present (per-filesystem).

## Btrfs
- mkfs
  - Single disk: mkfs.btrfs -f -L nixos $P2
  - Mirrored root: mkfs.btrfs -f -L nixos -m raid1 -d raid1 $P2A $P2B
- Subvolumes
  - @ (root), @home, @nix, @snapshots
- Mount options
  - compress=zstd, discard=async, noatime
- Mount layout
  - subvol=@ → /
  - subvol=@home → /home
  - subvol=@nix → /nix
  - subvol=@snapshots → /.snapshots
- Mirrored boot (optional)
  - Two ESPs are mounted at /boot and /boot2
  - boot.loader.systemd-boot.mirroredBoots configured to replicate to /boot2
- Guardrails
  - Refuses to run if any btrfs filesystems are mounted
- NixOS configuration hints
  - Btrfs is supported out-of-the-box; tools provided: btrfs-progs

Example
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
- Mount options
  - noatime
- NixOS configuration
```nix
services.fstrim.enable = true;
```

Example
```sh
mkfs.ext4 -F -L nixos "$P2"
mount -o noatime "$P2" /mnt
```

## XFS
- mkfs
  - mkfs.xfs -f -L nixos $P2
- Mount options
  - noatime
- NixOS configuration
```nix
services.fstrim.enable = true;
```

Example
```sh
mkfs.xfs -f -L nixos "$P2"
mount -o noatime "$P2" /mnt
```

## bcachefs (experimental)
- mkfs
  - mkfs.bcachefs -f --compression=zstd -L nixos $P2
- Subvolumes
  - @ (root), @home, @nix, @var, @var_log, @var_cache, @var_tmp, @var_lib
- Mount options
  - compress=zstd, noatime
- Guardrails
  - Requires explicit EXPERIMENT acknowledgement
  - Verifies kernel support (modprobe / /proc/filesystems)
  - Refuses to run if any bcachefs is mounted
- NixOS configuration
```nix
boot.supportedFilesystems = [ "bcachefs" ];
boot.initrd.supportedFilesystems = [ "bcachefs" ];
services.fstrim.enable = true;
```

Example
```sh
mkfs.bcachefs -f --compression=zstd -L nixos "$P2"
mount -o compress=zstd,noatime,subvol=/@ "/dev/disk/by-uuid/$FSUUID" /mnt
```

## ZFS
- Partitioning and EFI
  - ESP: FAT32, 1 GiB
  - Pool: uses the remaining space
- Pool creation (defaults)
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
- Datasets (legacy mountpoints)
  - $POOL/root (mountpoint=none); $POOL/root/nixos → /
  - $POOL/home → /home
  - $POOL/nix → /nix (atime=off)
  - $POOL/var (mountpoint=none);
    - $POOL/var/log → /var/log (exec=off, devices=off)
    - $POOL/var/cache → /var/cache (exec=off, devices=off, com.sun:auto-snapshot=false)
    - $POOL/var/tmp → /var/tmp (exec=off, devices=off, com.sun:auto-snapshot=false)
    - $POOL/var/lib → /var/lib
- Mirrored boot (optional)
  - Two ESPs mounted at /boot and /boot2; boot.loader.systemd-boot.mirroredBoots configured
  - Mirrored zpool (mirror vdev): zpool create ... mirror $P2A $P2B
- Guardrails
  - Verifies ZFS kernel module availability (lsmod/modprobe)
  - Refuses if any ZFS filesystems are mounted or any pools are imported
- NixOS configuration
```nix
boot.supportedFilesystems = [ "zfs" ];
boot.initrd.supportedFilesystems = [ "zfs" ];
networking.hostId = "<generated-8-hex-digits>"; # required for initrd import
services.zfs.autoScrub.enable = true;
services.fstrim.enable = true; # in addition to autotrim at the pool
```

Example mounts
```sh
mount -t zfs "$POOL/root/nixos" /mnt
mount -t zfs "$POOL/home" /mnt/home
mount -t zfs "$POOL/nix" /mnt/nix
mount -t zfs "$POOL/var/log" /mnt/var/log
mount -t zfs "$POOL/var/cache" /mnt/var/cache
mount -t zfs "$POOL/var/tmp" /mnt/var/tmp
mount -t zfs "$POOL/var/lib" /mnt/var/lib
```

