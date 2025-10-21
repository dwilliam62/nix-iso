# Filesystem installer defaults

This document summarizes the default parameters and settings used by the interactive installer scripts in scripts/ for each supported filesystem.

Notes
- Partitioning model (all installers): GPT with a 1 GiB EFI System Partition (FAT32) and the remainder allocated to the selected filesystem or pool.
- User input: timezone, keymap, hostname, username (with optional password hashing via openssl).
- Bootloader: systemd-boot on UEFI.
- zswap: enabled via kernelParams (z3fold, zstd) for broad compatibility.

## Btrfs
- mkfs
  - mkfs.btrfs -f -L nixos $P2
- Subvolumes
  - @ (root), @home, @nix, @snapshots
- Mount options
  - compress=zstd, discard=async, noatime
- Mount layout
  - subvol=@ → /
  - subvol=@home → /home
  - subvol=@nix → /nix
  - subvol=@snapshots → /.snapshots
- NixOS configuration hints
  - No special supportedFilesystems needed (Btrfs is supported out-of-the-box)
  - Tools provided: btrfs-progs

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

## bcachefs
- mkfs
  - mkfs.bcachefs -f --compression=zstd -L nixos $P2
- Mount options
  - noatime
- NixOS configuration
```nix
boot.supportedFilesystems = [ "bcachefs" ];
services.fstrim.enable = true;
```

Example
```sh
mkfs.bcachefs -f --compression=zstd -L nixos "$P2"
mount -o noatime "$P2" /mnt
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
  - $POOL/root → /
  - $POOL/home → /home
  - $POOL/nix → /nix
  - $POOL/snapshots → /.snapshots
- NixOS configuration
```nix
boot.supportedFilesystems = [ "zfs" ];
networking.hostId = "<generated-8-hex-digits>"; # required for initrd import
services.zfs.autoScrub.enable = true;
services.fstrim.enable = true; # in addition to autotrim at the pool
```

Example mounts
```sh
mount -t zfs "$POOL/root" /mnt
mount -t zfs "$POOL/home" /mnt/home
mount -t zfs "$POOL/nix" /mnt/nix
mount -t zfs "$POOL/snapshots" /mnt/.snapshots
```

