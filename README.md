English | [Español](./README.es.md)

# ddubsos NixOS Install/Recovery ISOs

---

<div align="center">
  <img src="img/nixos-install-cosmic-gui-1.png" alt="Screenshot: NixOS installation using XFS in the COSMIC Desktop GUI" width="80%" />
  <br />
  <em>Screenshot: NixOS installation using XFS in the COSMIC Desktop GUI</em>
</div>

### Custom NixOS install and recovery ISOs based on nixos-unstable, with a focus on

modern filesystem support (Btrfs, ZFS, XFS, ext4, bcachefs) and a robust
recovery toolset.

Credits

- This repository is a derivative of, and heavily inspired by, the work in
  JohnRTitor/nix-iso.
  - Upstream project: https://github.com/JohnRTitor/nix-iso
- We maintain a fork with our own profiles, tooling, and documentation tailored
  for rescue and repeatable installs.

What this project provides

- Multiple ISO profiles, all including the recovery toolset by default:
  - Minimal (nixos-minimal)
  - GNOME (nixos-gnome)
- COSMIC (nixos-cosmic, experimental)
- Recovery (nixos-recovery)
- NixOS UNSTABlE install scripts supporting
  - ZFS
  - BTRFS
  - XFS
  - EXT4
  - bcachefs
- Documentation for the OS install scripts is below
- There are dedicated links for each of the scripts below

Note about live ISO GUIs: The GNOME and COSMIC profiles change only the live ISO
user interface. The installers do NOT install GNOME or COSMIC onto the target
system; they install a base NixOS. You can add a desktop environment after the
initial install.

- Modern kernel and ZFS package selection via chaotic nyx for broader
  hardware/filesystem support.
- Full filesystem tooling for installs and rescue:
  - Btrfs: btrfs-progs (subvolumes @, @home, @nix, @snapshots)
  - ext4: e2fsprogs
  - XFS: xfsprogs
  - bcachefs: bcachefs-tools (mkfs with zstd compression support)
  - ZFS: userland (zpool, zfs) sourced from config.boot.zfs.package for kernel
    compatibility
  - NFS/SMB: nfs-utils, cifs-utils
  - Plus: ntfs3g, exfatprogs, dosfstools
- Recovery/imaging and diagnostics: ddrescue, testdisk, smartmontools, nvme-cli,
  hdparm, pciutils/usbutils, and more.
- All profiles bundle the scripts/ directory into $PATH on the live ISO for
  convenience.

Destructive operations warning

- The installer scripts will repartition and format the selected disk. This
  destroys all data on that disk.
- Read all prompts carefully. The scripts require typing INSTALL to proceed as a
  safety check.

How to build the ISOs

- Prereqs: enable flakes and accept flake config (see below for cache settings).
- Clone:
  - git clone https://github.com/dwilliam62/nix-iso.git
  - cd nix-iso
  - Suggest running `nix flake update`

Preferred (helper script)

- Use the helper to avoid long attribute paths. It also defaults
  NIXPKGS_ALLOW_BROKEN=1 to match historical behavior.
  ```
  # Minimal ISO
  ./scripts/build-iso.sh minimal

  # GNOME ISO
  ./scripts/build-iso.sh gnome

  # COSMIC ISO (experimental)
  ./scripts/build-iso.sh cosmic

  # Recovery ISO
  ./scripts/build-iso.sh nixos-recovery
  ```
- The script accepts friendly aliases and common typos (see scripts/build-iso.sh
  header for details).
- Result: the ISO image will be in ./result/iso/

Advanced/manual build

- If you prefer raw nix build commands:
  ```
  # Minimal
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
  # GNOME
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-gnome.config.system.build.isoImage --impure
  # COSMIC
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-cosmic.config.system.build.isoImage --impure
  # Recovery
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-recovery.config.system.build.isoImage --impure
  ```

Binary caches (strongly recommended)

- To avoid building the kernel and ZFS from source, configure caches on the
  build host:

What gets installed by the scripts

- Base system only: a minimal NixOS with a generated
  /etc/nixos/configuration.nix. No desktop environment is installed by these
  scripts.
- Bootloader: systemd-boot on UEFI. Mirrored installers also configure
  systemd-boot.mirroredBoots to replicate the bootloader to /boot2.
- Filesystems and layout: installers create opinionated layouts per filesystem
  for reliable operation and clean snapshots:
  - ZFS: rpool/root (container) + rpool/root/nixos → /; datasets for /home, /nix
    (atime=off), and split /var (log/cache/tmp/lib). Legacy mountpoints are used
    for ZFS datasets. ZFS hostId is generated for initrd import.
  - Btrfs: subvolumes @ → /, @home → /home, @nix → /nix, @snapshots →
    /.snapshots. Mirrored variant uses RAID1 (-m raid1 -d raid1).
  - bcachefs (experimental): subvolumes @ → /, @home → /home, @nix → /nix, and
    split /var into @var_log, @var_cache, @var_tmp, @var_lib.
- Services and defaults:
  - NetworkManager enabled; OpenSSH enabled; sudo for wheel with password.
  - zswap enabled via kernelModules + kernelParams (z3fold + zstd).
  - fstrim service enabled (ext4/XFS/bcachefs); ZFS autotrim is set at pool
    creation.
- Nix settings:
  - nixpkgs.config.allowUnfree = true
  - nix.settings.experimental-features = [ "nix-command" "flakes" ] (flakes
    enabled by default)
- Safety: installers require an INSTALL confirmation before destructive actions
  and include environment guardrails (container/UEFI notices, conflicting mount
  checks).

NixOS (recommended) nix.settings = { experimental-features = [ "nix-command"
"flakes" ]; accept-flake-config = true; substituters = [
"https://cache.nixos.org" "https://nix-community.cachix.org"
"https://nyx.chaotic.cx/" ]; trusted-public-keys = [
"nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
"nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=" ]; };

Non-NixOS (multi-user daemon) accept-flake-config = true substituters =
https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/
trusted-public-keys =
nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=

Using the installer scripts (on the live ISO or any NixOS live env)

- Available scripts in `~/nix-iso/scripts`:
  - install-btrfs.sh — Btrfs with subvolumes @, @home, @nix, @snapshots; zstd
    compression
  - install-ext4.sh — ext4 installer (enable fstrim in config)
  - install-xfs.sh — XFS installer (enable fstrim in config)
  - install-zfs.sh — ZFS with sensible defaults; legacy mountpoints; generates
    networking.hostId
  -
  > The following scripts should be considered EXPERMIMENTAL They are currently
  > a work-in-progress (Aug 2025) None should be used for production purposes of
  > any kind. _You have been warned!_
  -
  - install-bcachefs.sh — bcachefs with --compression=zstd
  - install-zfs-boot-mirror.sh — ZFS mirroring on boot drive
  - install-btrfs-boot-mirror.sh — Btrfs mirroring on boot drive

- Run as root; the scripts will self-elevate via sudo when possible:
  ```
  sudo ./scripts/install-btrfs.sh
  # or install-ext4.sh, install-xfs.sh, install-bcachefs.sh, install-zfs.sh
  ```

Mirror installers (experimental; use at your own risk)

- Scripts: scripts/install-zfs-boot-mirror.sh and
  scripts/install-btrfs-boot-mirror.sh
- Purpose: set up a mirrored root (ZFS/Btrfs) and two EFI System Partitions
  (/boot and /boot2). On newer nixpkgs, systemd-boot can automatically replicate
  the bootloader to /boot2.
- Compatibility:
  - The auto-replication relies on the nixpkgs option
    boot.loader.systemd-boot.mirroredBoots. The installers detect its presence
    and enable it when available.
  - On older nixpkgs snapshots that don’t provide this option, installs still
    succeed; only the auto-sync of /boot -> /boot2 is skipped. The ZFS/Btrfs
    storage mirrors are unaffected.
  - To ensure current features on the live ISO, update this repo’s flake.lock
    (nix flake update) and rebuild the ISO.

> Warning: these mirror installers are experimental and not intended for
> production use. Use at your own risk. Test thoroughly, keep backups, and
> ensure you have a fallback boot path (e.g., firmware boot entry for the second
> ESP).

Notes on defaults

- Partitioning: GPT with 1 GiB EFI System Partition (FAT32) + remainder for the
  chosen filesystem.
- Bootloader: systemd-boot on UEFI.
- zswap: enabled via kernelParams (zstd, z3fold) for broad compatibility.
- Users: scripts prompt for a user and hash the password with openssl -6 if
  available.
- Generated configuration: includes a reasonable base set of tools and enables
  NetworkManager and SSH.

Included tools overview

- See Tools-Included.md for the complete, up-to-date list of tools packaged into
  the live ISO.
- Documentation is available on the live ISO under /etc/nix-iso-docs (README.md,
  HOWTO.md, Tools-Included.md, docs/*).

Documentation

- Filesystem overview:
  [docs/filesystems-overview.md](docs/filesystems-overview.md)
- Defaults and parameters:
  [docs/filesystem-defaults.md](docs/filesystem-defaults.md)
- Package dependencies:
  [docs/package-dependencies.md](docs/package-dependencies.md)
- Quickstarts:
  - ZFS (single disk): [docs/quickstart-zfs.md](docs/quickstart-zfs.md)
  - ZFS (mirrored):
    [docs/quickstart-zfs-mirror.md](docs/quickstart-zfs-mirror.md)
  - Btrfs (single disk): [docs/quickstart-btrfs.md](docs/quickstart-btrfs.md)
  - Btrfs (mirrored):
    [docs/quickstart-btrfs-mirror.md](docs/quickstart-btrfs-mirror.md)
  - bcachefs (experimental):
    [docs/quickstart-bcachefs.md](docs/quickstart-bcachefs.md)
- Btrfs non-interactive playbook:
  [docs/nixos-btrfs-install.md](docs/nixos-btrfs-install.md)

License and contributions

- Licensed under Apache-2.0 (see LICENSE). Spanish translation:
  [LICENSE.es.md](./LICENSE.es.md) (non-authoritative). Third-party software
  remains under their respective licenses.
- Contributions are welcome via issues and PRs.

Disclaimer

- While we strive for safe defaults, use at your own risk. Always back up
  important data before running destructive operations.
