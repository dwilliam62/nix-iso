# Filesystem installer scripts

These scripts perform interactive, opinionated NixOS installations for multiple filesystems. They are designed to be run from the live ISO or any environment with the needed tools available.

Common flow across all installers
- Prompts for timezone, console keymap, hostname, and username (with secure password hashing if openssl is present)
- Lets you select the target disk from detected devices
- Confirms with a mandatory "INSTALL" to avoid accidents
- Partitions the target as:
  - 1 GiB EFI System Partition (vfat)
  - Remaining space as the selected filesystem
- Generates hardware-configuration.nix
- Writes /etc/nixos/configuration.nix from a safe template:
  - systemd-boot UEFI boot
  - zswap via kernelParams (z3fold)
  - NetworkManager enabled
  - sudo wheel members require password (wheelNeedsPassword = true)
  - unfree allowed; flakes enabled
- Runs nixos-install (you will be prompted to set the root password)

Available installers
- install-btrfs.sh
  - Filesystem: Btrfs
  - Layout: subvolumes @ (root), @home, @nix, @snapshots
  - Mount opts: compress=zstd, discard=async, noatime
  - Notes: includes /.snapshots for tools like snapper

- install-ext4.sh
  - Filesystem: ext4
  - Mount opts: noatime
  - Notes: ext4 has no native transparent compression; enable fstrim timer in configuration

- install-xfs.sh
  - Filesystem: XFS
  - Mount opts: noatime
  - Notes: XFS has no native transparent compression; enable fstrim timer in configuration

- install-bcachefs.sh
  - Filesystem: bcachefs
  - mkfs opts: --compression=zstd
  - Mount opts: noatime
  - Configuration: boot.supportedFilesystems = [ "bcachefs" ]

- install-zfs.sh
  - Filesystem: ZFS (single-disk pool by default)
  - zpool create options: ashift=12, autotrim=on, compression=zstd, atime=off, xattr=sa, acltype=posixacl, mountpoint=none, -R /mnt
  - Datasets: rpool/root, rpool/home, rpool/nix, rpool/snapshots (legacy mountpoints)
  - Configuration: boot.supportedFilesystems = [ "zfs" ], a unique networking.hostId is generated for initrd import
  - Services: services.zfs.autoScrub.enable = true

How to run
- Run as root. The scripts self-elevate via sudo if possible.

Examples
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

Docs on the live ISO
- Find docs under /etc/ddubsos-docs (README.md, HOWTO.md, Tools-Included.md, and docs/*).

Notes
- These scripts destroy data on the selected disk. Read prompts carefully.
- Root password is set interactively by nixos-install; the user account password is hashed and written when possible.
- For ZFS, dataset layout can be customized (e.g., separate datasets for /var, /var/log). Adjust the script or configure post-install.
- For ext4/XFS, compression is not available; fstrim is enabled via configuration.

