# ddubsos NixOS Install/Recovery ISOs

Custom NixOS install and recovery ISOs based on nixos-unstable, with a focus on modern filesystem support (Btrfs, ZFS, XFS, ext4, bcachefs) and a robust recovery toolset.

Credits
- This repository is a derivative of, and heavily inspired by, the work in JohnRTitor/nix-iso.
  - Upstream project: https://github.com/JohnRTitor/nix-iso
- We maintain a fork with our own profiles, tooling, and documentation tailored for rescue and repeatable installs.

What this project provides
- Multiple ISO profiles, all including the recovery toolset by default:
  - Minimal (nixos-minimal)
  - GNOME (nixos-gnome)
  - COSMIC (nixos-cosmic, experimental)
  - Recovery (nixos-recovery)
- Modern kernel and ZFS package selection via chaotic nyx for broader hardware/filesystem support.
- Full filesystem tooling for installs and rescue:
  - Btrfs: btrfs-progs (subvolumes @, @home, @nix, @snapshots)
  - ext4: e2fsprogs
  - XFS: xfsprogs
  - bcachefs: bcachefs-tools (mkfs with zstd compression support)
  - ZFS: userland (zpool, zfs) sourced from config.boot.zfs.package for kernel compatibility
  - NFS/SMB: nfs-utils, cifs-utils
  - Plus: ntfs3g, exfatprogs, dosfstools
- Recovery/imaging and diagnostics: ddrescue, testdisk, smartmontools, nvme-cli, hdparm, pciutils/usbutils, and more.
- All profiles bundle the scripts/ directory into $PATH on the live ISO for convenience.

Destructive operations warning
- The installer scripts will repartition and format the selected disk. This destroys all data on that disk.
- Read all prompts carefully. The scripts require typing INSTALL to proceed as a safety check.

How to build the ISOs
- Prereqs: enable flakes and accept flake config (see below for cache settings).
- Clone:
  - git clone https://github.com/dwilliam62/nix-iso.git
  - cd nix-iso

Preferred (helper script)
- Use the helper to avoid long attribute paths. It also defaults NIXPKGS_ALLOW_BROKEN=1 to match historical behavior.
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
- The script accepts friendly aliases and common typos (see scripts/build-iso.sh header for details).
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
- To avoid building the kernel and ZFS from source, configure caches on the build host:

NixOS (recommended)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    accept-flake-config = true;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nyx.chaotic.cx/"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
    ];
  };

Non-NixOS (multi-user daemon)
  accept-flake-config = true
  substituters = https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/
  trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=

Using the installer scripts (on the live ISO or any NixOS live env)
- Available scripts in scripts/:
  - install-btrfs.sh — Btrfs with subvolumes @, @home, @nix, @snapshots; zstd compression
  - install-ext4.sh — ext4 installer (enable fstrim in config)
  - install-xfs.sh — XFS installer (enable fstrim in config)
  - install-bcachefs.sh — bcachefs with --compression=zstd
  - install-zfs.sh — ZFS with sensible defaults; legacy mountpoints; generates networking.hostId
- Run as root; the scripts will self-elevate via sudo when possible:
  ```
  sudo ./scripts/install-btrfs.sh
  # or install-ext4.sh, install-xfs.sh, install-bcachefs.sh, install-zfs.sh
  ```

Notes on defaults
- Partitioning: GPT with 1 GiB EFI System Partition (FAT32) + remainder for the chosen filesystem.
- Bootloader: systemd-boot on UEFI.
- zswap: enabled via kernelParams (zstd, z3fold) for broad compatibility.
- Users: scripts prompt for a user and hash the password with openssl -6 if available.
- Generated configuration: includes a reasonable base set of tools and enables NetworkManager and SSH.

Included tools overview
- See Tools-Included.md for the complete, up-to-date list of tools packaged into the live ISO.
- Documentation is available on the live ISO under /etc/ddubsos-docs (README.md, HOWTO.md, Tools-Included.md, docs/*).

Documentation
- Filesystem overview: [docs/filesystems-overview.md](docs/filesystems-overview.md)
- Defaults and parameters: [docs/filesystem-defaults.md](docs/filesystem-defaults.md)
- Quickstarts:
  - ZFS (single disk): [docs/quickstart-zfs.md](docs/quickstart-zfs.md)
  - ZFS (mirrored): [docs/quickstart-zfs-mirror.md](docs/quickstart-zfs-mirror.md)
  - Btrfs (single disk): [docs/quickstart-btrfs.md](docs/quickstart-btrfs.md)
  - Btrfs (mirrored): [docs/quickstart-btrfs-mirror.md](docs/quickstart-btrfs-mirror.md)
  - bcachefs (experimental): [docs/quickstart-bcachefs.md](docs/quickstart-bcachefs.md)
- Btrfs non-interactive playbook: [docs/nixos-btrfs-install.md](docs/nixos-btrfs-install.md)

License and contributions
- Licensed under Apache-2.0 (see LICENSE). Third-party software remains under their respective licenses.
- Contributions are welcome via issues and PRs.

Disclaimer
- While we strive for safe defaults, use at your own risk. Always back up important data before running destructive operations.
