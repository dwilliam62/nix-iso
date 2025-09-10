<!--
Author: Don Williams (aka ddubs)
Created: 2025-09-10
Project: https://github.com/dwilliam62/nix-iso
-->

# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- Purpose: Build custom NixOS install/recovery ISOs with modern filesystem installers and a bundled recovery toolset.
- Profiles (flake outputs): nixos-minimal, nixos-gnome, nixos-cosmic (experimental), nixos-recovery.
- Key entry points:
  - flake.nix (defines profiles and formatter)
  - common.nix (shared system settings, kernel/ZFS, overlays, base tools)
  - recovery/recovery-tools.nix (bundled scripts/docs, live ISO packages, launchers)
  - scripts/ (ISO build helper, TUI launcher and modules, installers)

Common commands
- Build ISO via helper (sets NIXPKGS_ALLOW_BROKEN=1 by default)
  ```bash path=null start=null
  # Minimal
  ./scripts/build-iso.sh minimal

  # GNOME
  ./scripts/build-iso.sh gnome

  # COSMIC (experimental)
  ./scripts/build-iso.sh cosmic

  # Recovery ISO
  ./scripts/build-iso.sh nixos-recovery
  ```
- Manual ISO build via flake
  ```bash path=null start=null
  # Minimal
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
  # GNOME
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-gnome.config.system.build.isoImage --impure
  # COSMIC
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-cosmic.config.system.build.isoImage --impure
  # Recovery
  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-recovery.config.system.build.isoImage --impure
  # Result: ./result/iso/
  ```
- Format Nix code (uses flake formatter nixfmt-rfc-style)
  ```bash path=null start=null
  nix fmt
  ```
- Basic validation
  ```bash path=null start=null
  nix flake check
  ```
- Update inputs
  ```bash path=null start=null
  nix flake update
  ```

Caches
- Builds are faster with caches. This flake sets extra substituters/keys:
  - https://nyx.chaotic.cx/
  - https://nix-community.cachix.org
- On CI, accept-flake-config and experimental-features are enabled; do the same locally if needed.

Architecture and structure
1) Flake topology (flake.nix)
- Inputs: nixpkgs (nixos-unstable), chaotic nyx (bleeding-edge kernel/ZFS), bcachefs-tools.
- Outputs:
  - formatter.${system} → nixfmt-rfc-style
  - nixosConfigurations:
    - nixos-minimal → ./minimal
    - nixos-gnome → ./gnome
    - nixos-cosmic → ./cosmic (imports ./cosmic/cosmic.nix)
    - nixos-recovery → ./recovery
- nixConfig provides substituters and trusted keys used when running the flake directly.

2) Shared system layer (common.nix)
- Enables flakes and nix-command; allowUnfree and env var NIXPKGS_ALLOW_UNFREE.
- Overlays:
  - bcachefs-tools wired from inputs for the active system
  - Workarounds: disable tests for python pkgs (pygls, i3ipc) to avoid upstream breakage on Python 3.13
- Kernel and ZFS:
  - boot.kernelPackages = linuxPackages_cachyos
  - boot.zfs.package = zfs_cachyos (override to ensure compatibility)
- Filesystems support: btrfs, vfat, f2fs, xfs, ntfs, cifs, bcachefs, ext4, zfs
- Base packages and live conveniences (vim, git, parted, efibootmgr, tmux) and a conservative, portable /etc/tmux.conf

3) Recovery/tooling layer (recovery/recovery-tools.nix)
- Packages two derivations into the ISO:
  - recoveryScripts: places scripts/* into PATH (chmod +x)
  - nixIsoDocs: copies project docs, converts README(.es) to HTML via pandoc, exposes under /etc/nix-iso-docs
- Adds extensive recovery/storage/network CLI tools (btrfs-progs, e2fsprogs, xfsprogs, bcachefs-tools, zfs userland via config.boot.zfs.package, ddrescue, testdisk, smartmontools, nvme-cli, etc.)
- Provides desktop entries and hints for launching the TUI and docs in live sessions (GNOME/COSMIC); ensures presence on the live user’s Desktop
- Seeds a starter /etc/nixos/configuration.nix for quick installs (edit before nixos-install)

4) Profiles
- minimal/default.nix: imports installation-cd-minimal, common.nix, and recovery-tools; sets hostName and console hint to run “nix-iso”; custom ISO naming.
- gnome/default.nix: imports graphical GNOME installer and channel; adds dconf profile to enable Desktop Icons NG (attribute name fallback handled); hostName, networking tweaks, custom ISO naming.
- cosmic/default.nix + cosmic/cosmic.nix: imports graphical base + cosmic greeter; enables services.desktopManager.cosmic with xwayland; autoLogin to user nixos; custom ISO naming.
- recovery/default.nix: imports minimal installer, channel, common.nix, and recovery-tools; distinct ISO filename for recovery.

5) TUI installer (scripts/nix-iso and modules)
- scripts/nix-iso: modular shell TUI framework. Discovers modules from scripts/tui/modules and registers sections/items via helpers from scripts/tui/lib.sh.
- scripts/tui/lib.sh: registry and UI helpers (register_section, register_item, register_header; color/confirm utilities).
- scripts/tui/modules/installers.sh: adds menu items for installers, marking experimental/testing entries with warnings.
- scripts/tui/modules/docs.sh: opens offline docs (/etc/nix-iso-docs) and the GitHub repo; adapts between GUI and TTY.

6) Build helper (scripts/build-iso.sh)
- Normalizes profile aliases (minimal/gnome/cosmic → nixos-*) and defaults to nixos-minimal.
- Exports NIXPKGS_ALLOW_BROKEN=1 unless already set, then runs the corresponding nix build command.

CI/CD
- .github/workflows/check-flake.yml: nix flake check on push/PR/dispatch (accepts flake config, enables experimental features).
- .github/workflows/update-flake.yml: weekly lockfile update; also runs on manual dispatch or when flake.nix changes.
- .github/workflows/build-and-release.yml: after lockfile update (or manual), builds nixos-minimal ISO and uploads artifact (result/iso/* as Unstable-ISO.iso).

Notes for contributors
- When adding a new profile:
  - Create a directory with default.nix that imports the appropriate installer module(s), ../common.nix, and ../recovery/recovery-tools.nix.
  - Add a nixosConfigurations.<name> entry in flake.nix pointing modules = [ ./<dir> ].
  - Customize image.fileName/isoName via lib.mkForce for distinct artifact naming.
- The live ISO bundles scripts/ into PATH; new installers should be added under scripts/ and registered in scripts/tui/modules/installers.sh.

