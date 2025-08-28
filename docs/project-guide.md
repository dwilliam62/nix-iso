<!--
Author: Don Williams (aka ddubs)
Created: 2025-08-27
Project: https://github.com/dwilliam62/nix-iso
-->

English | Español (TBD)

# Project Guide — nix-iso: Custom NixOS Install/Recovery ISOs

Purpose
- Build custom NixOS live ISOs (minimal, GNOME, COSMIC, recovery) focused on installation and recovery.
- Provide interactive installer scripts for multiple filesystems (ZFS, Btrfs, XFS, ext4, bcachefs), plus experimental mirrored-boot variants.
- Bundle a robust recovery toolset and offline documentation directly in the ISO.

Quick start
- Build with helper:
  - Minimal: ./scripts/build-iso.sh minimal
  - GNOME: ./scripts/build-iso.sh gnome
  - COSMIC: ./scripts/build-iso.sh cosmic (experimental)
  - Recovery: ./scripts/build-iso.sh nixos-recovery
- Manual (example):
  - env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
- Boot the ISO, open a terminal, run: nix-iso (TUI installer + docs menu)
- Offline docs in the live system: /etc/nix-iso-docs

Safety notes
- All install scripts are destructive to the selected target disk. They repartition and format it.
- Scripts require typing INSTALL before proceeding to mitigate accidents.
- Read prompts carefully; ensure you’re on the correct host (not inside a container) and that UEFI variables are available when needed.

Repository structure (high level)
- flake.nix — Defines nixosConfigurations for: nixos-minimal, nixos-gnome, nixos-cosmic, nixos-recovery. Sets inputs:
  - nixpkgs (nixos-unstable), chaotic nyx (bleeding-edge pkgs like CachyOS kernel)
  - Exposes a formatter and cache hints via nixConfig
- common.nix — Shared base config across profiles:
  - allowUnfree, nix-command + flakes, bcachefs-tools overlay, python test overrides
  - kernel: linuxPackages_cachyos; ZFS: zfs_cachyos; supported filesystems include btrfs, xfs, ext4, bcachefs, zfs, etc.
  - baseline tooling (vim, git, curl, parted, efibootmgr, tmux) and guest services
  - provides a friendly /etc/tmux.conf
- profiles/
  - minimal/default.nix — Minimal ISO imports: installation-cd-minimal.nix, ../common.nix, ../recovery/recovery-tools.nix
  - gnome/default.nix — Graphical GNOME ISO imports graphical installer module + channel.nix, then common + recovery-tools
  - cosmic/default.nix + cosmic/cosmic.nix — COSMIC desktop ISO configuration (experimental)
  - recovery/default.nix — Recovery ISO (channel + minimal base), imports ./recovery-tools.nix
- recovery/recovery-tools.nix — Key module that:
  - Bundles repository scripts into PATH on the ISO
  - Builds and exposes offline documentation at /etc/nix-iso-docs (Markdown + HTML via pandoc)
  - Adds desktop/app grid entries for quick access to docs and the installer TUI
  - Enables NetworkManager, SSH (permit root login on live media), and ships a large recovery toolset
- scripts/
  - build-iso.sh — Helper wrapper for nix build commands
  - install-*.sh — Interactive installers per filesystem (btrfs, ext4, xfs, zfs, bcachefs) and experimental mirrored variants
  - nix-iso, nix-iso-run-in-terminal — TUI launcher wrappers
  - tui/ — TUI modules (docs and installers menus)
- docs/
  - filesystems-overview.md — Layouts, mirrored boot overview, guardrails
  - filesystem-defaults.md — mkfs/mount options and defaults by FS
  - package-dependencies.md — Host/runtime package needs
  - quickstart-*.md — Step-by-step per-FS guides (incl. experimental mirror variants)
- Top-level docs — README.md, HOWTO.md, Tools-Included.md (English + Spanish where available)

How the ISO profiles are built
- Each ISO profile imports the upstream NixOS installer module appropriate to that profile (e.g., minimal or graphical) plus channel.nix where required.
- All profiles import common.nix (shared config) and recovery/recovery-tools.nix (shared toolset, TUI launcher, offline docs).
- Filenames are customized to nixos-ddubsos-<profile>-<nixosVersion>-<arch>.iso for clarity.

Included toolset (summary)
- Storage/filesystems: btrfs-progs, e2fsprogs, xfsprogs, bcachefs-tools, ntfs3g, exfatprogs, dosfstools, nfs-utils, cifs-utils
- Partitioning/boot: parted, gptfdisk, efibootmgr
- ZFS userland via config.boot.zfs.package to match the running kernel
- Recovery/diagnostics: ddrescue, testdisk, smartmontools, hdparm, nvme-cli, pciutils, usbutils
- CLI/UI: coreutils, busybox, ripgrep, (neo)vim, nano, tmux, curl, wget, rsync, jq, yq-go
- Snapshot/backup helpers: snapper, btrbk
- Offline docs: pandoc-generated HTML + Markdown under /etc/nix-iso-docs

Installer behavior (common flow)
- Prompts for timezone, keymap, hostname, username (hashes user password when possible)
- Selects a target disk and confirms via INSTALL
- Partitions GPT: 1 GiB EFI System Partition (FAT32) + remainder for the chosen filesystem
- Generates hardware-configuration.nix
- Writes a safe /etc/nixos/configuration.nix template (systemd-boot, zswap via kernelParams, NetworkManager, unfree allowed, flakes enabled)
- Runs nixos-install (sets root password interactively)

Filesystem layouts (brief)
- ZFS: rpool/root (container) + rpool/root/nixos → /, plus datasets for /home, /nix, /var/*; legacy mountpoints; generates networking.hostId
- Btrfs: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots; mirrored variant uses RAID1 and dual ESPs (/boot, /boot2)
- bcachefs (experimental): @ → /, @home → /home, @nix → /nix, @var*, with compression=zstd
- ext4, XFS: simple layouts; enable fstrim timer in config

Mirrored boot (experimental scripts)
- Dual ESPs mounted at /boot and /boot2; boot.loader.systemd-boot.mirroredBoots is enabled when available in nixpkgs
- Mirrored root for ZFS/Btrfs installers uses appropriate mkfs/pool creation flags
- Backwards compatibility: If mirroredBoots isn’t available in the live ISO’s nixpkgs, install proceeds without auto-replication to /boot2

Binary caches
- Strongly recommended to avoid building kernels/ZFS from source during ISO builds.
- This flake exposes nixConfig with extra-substituters and extra-trusted-public-keys (chaotic nyx and nix-community). Consider enabling accept-flake-config and matching substituters/trusted keys on build hosts.

TUI and docs on the live ISO
- TUI: launch via nix-iso (also a desktop/app grid entry in graphical ISOs)
- Docs: /etc/nix-iso-docs (Markdown and HTML); desktop/app grid shortcuts included on live media

Development and customization
- Update nixpkgs inputs: nix flake update
- Change architecture: edit system in flake.nix (default x86_64-linux)
- Add a profile: create a new directory with default.nix that imports the proper upstream installer module(s), then include ../common.nix and ../recovery/recovery-tools.nix
- Adjust toolset: modify recovery/recovery-tools.nix environment.systemPackages
- ISO naming: image.fileName is set in each profile to a distinctive name; you can add isoImage.isoName if desired

For AI and automation (key facts)
- Build attributes:
  - .#nixosConfigurations.nixos-minimal.config.system.build.isoImage
  - .#nixosConfigurations.nixos-gnome.config.system.build.isoImage
  - .#nixosConfigurations.nixos-cosmic.config.system.build.isoImage
  - .#nixosConfigurations.nixos-recovery.config.system.build.isoImage
- Entrypoints and critical files:
  - flake.nix (profiles, inputs)
  - common.nix (shared config, kernel/ZFS selection, overlays)
  - recovery/recovery-tools.nix (scripts + docs packaging, services, launchers)
  - scripts/install-*.sh (installers), scripts/build-iso.sh (build helper), scripts/nix-iso (TUI)
  - docs/* (reference, defaults, quickstarts)
- Live ISO docs path: /etc/nix-iso-docs
- Live TUI command: nix-iso
- Profiles to build: minimal, gnome, cosmic, nixos-recovery

Deep dive: install-*.sh scripts (core of this fork)
- All installers are Bash scripts designed for repeatable, basic NixOS 25.11 installs. They share a common flow and safety model, then diverge on fs-specific steps.

Shared conventions and guardrails
- Shell safety: set -euo pipefail.
- Root required: scripts re-exec via sudo -E if not root.
- PATH hygiene: prepend /usr/sbin, /sbin, /usr/local/sbin, and /run/current-system/sw/bin.
- Dependency checks: each script validates needed tools (parted, mkfs.*, mount, nixos-generate-config, nixos-install, etc.).
- Environment warnings:
  - Warn if running in a container (systemd-detect-virt --container).
  - Note when UEFI efivars are missing (/sys/firmware/efi/efivars).
  - Refuse to run if conflicting filesystems are mounted for that installer (e.g., Btrfs/ZFS/bcachefs).
  - ZFS/bcachefs: verify kernel/module availability (modprobe/lsmod or /proc/filesystems).
- Destructive confirmation: requires typing INSTALL before partitioning/wiping.
- Device selection: interactive menu from lsblk, supports direct device input (/dev/sdX, /dev/nvmeXnY). Validates block device and read-only state via blockdev --getro.
- Partition scheme: GPT with 1 GiB ESP (FAT32) + remainder for filesystem/pool. Handles nvme/mmcblk partition naming (p suffix).
- Base configuration written by each installer:
  - systemd-boot UEFI; efi.canTouchEfiVariables = true
  - zswap via kernelModules + kernelParams (z3fold + zstd)
  - networking.networkmanager.enable = true; firewall.enable = false
  - users: creates requested username in wheel/networkmanager/input; hashes password via openssl -6 if available
  - nixpkgs.config.allowUnfree = true; nix.settings.experimental-features = [ "nix-command" "flakes" ]; accept-flake-config = true
  - services.openssh.enable = true; services.fstrim.enable for non-CoW FS where relevant
  - system.stateVersion = "25.11"
- Environment overrides: scripts respect TIMEZONE, KEYMAP, HOSTNAME, USERNAME; ZFS scripts also accept POOL.

Per-filesystem installers
- install-btrfs.sh
  - mkfs: mkfs.btrfs -f -L nixos $P2
  - Subvolumes: @ (root), @home, @nix, @snapshots
  - Mount options: compress=zstd, discard=async, noatime
  - Mount layout: subvol=@ → /; subvol=@home → /home; subvol=@nix → /nix; subvol=@snapshots → /.snapshots; ESP → /boot
  - Config: standard base; fstrim is not required specifically for Btrfs

- install-ext4.sh
  - mkfs: mkfs.ext4 -F -L nixos $P2
  - Mount options: noatime; ESP → /boot
  - Config: services.fstrim.enable = true

- install-xfs.sh
  - mkfs: mkfs.xfs -f -L nixos $P2
  - Mount options: noatime; ESP → /boot
  - Config: services.fstrim.enable = true

- install-bcachefs.sh (experimental)
  - Kernel guard: verifies bcachefs support (modprobe or /proc/filesystems); refuses to run otherwise
  - Explicit EXPERIMENT acknowledgement required (type EXPERIMENT)
  - mkfs: mkfs.bcachefs -f --compression=zstd -L nixos $P2
  - Subvolumes: root, home, nix, var, var-log, var-cache, var-tmp, var-lib (avoids '@' names)
  - Mounting: uses device by-uuid when available; mounts named subvolumes; sets nodev/noexec on var/log and var/cache
  - Config: sets boot.supportedFilesystems/initrd.supportedFilesystems = [ "bcachefs" ]; declares all fileSystems entries explicitly with subvolume options; services.fstrim.enable = true
  - Note: harmless btrfs-probing messages may appear in some environments; script warns they’re ignorable

- install-zfs.sh
  - Kernel guard: ensures zfs module available (lsmod/modprobe); refuses to run if any ZFS mounts or imported pools exist
  - Warning: notes potential kernel/ZFS ABI drift; recommends using matching kernel+ZFS (e.g., cachyos pairs) or pinning nixpkgs
  - Partition: ESP + pool on remaining space
  - zpool create options: ashift=12, autotrim=on, compression=zstd, atime=off, xattr=sa, acltype=posixacl, mountpoint=none, -R /mnt
  - Datasets: root (container), root/nixos (legacy → /), home (legacy → /home), nix (legacy → /nix, atime=off), var container with var/log, var/cache, var/tmp, var/lib (all legacy), with exec/devices tuning and auto-snapshot disables for cache/tmp
  - Mount: mount -t zfs for each dataset; ESP → /boot
  - Config: boot.supportedFilesystems = [ "zfs" ]; generates networking.hostId for initrd import; services.zfs.autoScrub.enable = true; services.fstrim.enable = true
  - Environment: POOL name prompt with default rpool

Mirrored boot installers (experimental)
- General
  - Require two completely unmounted disks; validate read-only status; warn if sizes differ (usable capacity ~= smaller disk)
  - Partition both disks identically; mount ESPs at /boot and /boot2
  - Configuration includes commented-out example for boot.loader.systemd-boot.mirroredBoots to avoid recursion on older nixpkgs; can be enabled when supported

- install-btrfs-boot-mirror.sh
  - mkfs: mkfs.btrfs -f -L nixos -m raid1 -d raid1 $P2A $P2B
  - Subvolumes: @, @home, @nix, @snapshots
  - Mounts: compress=zstd, discard=async, noatime; /boot and /boot2 mounted from each disk’s ESP
  - Config: includes commented mirroredBoots with devices = [ "/dev/disk/by-uuid/${UUID_B}" ] for /boot2

- install-zfs-boot-mirror.sh
  - zpool: zpool create ... mirror $P2A $P2B with the same safe defaults as single-disk ZFS
  - Datasets/mounts: identical to single-disk ZFS; /boot and /boot2 mounted from each ESP
  - Config: boot.supportedFilesystems/initrd.supportedFilesystems include "zfs"; commented mirroredBoots example for /boot2; networking.hostId generated; services.zfs.autoScrub enabled

Error handling and edge cases captured by scripts
- nvme/mmcblk partition suffix handling (p1/p2)
- Refusal to proceed when target disk appears mounted
- Use of /proc/self/mounts for precise fstype checks
- udevadm settle in bcachefs to stabilize by-uuid symlinks before mounting
- zswap defaults applied uniformly across installers

Known caveats
- Experimental pieces:
  - COSMIC profile
  - bcachefs installer
  - mirrored boot installers (ZFS, Btrfs)
- Container/UEFI limitations:
  - Running inside containers prevents access to block devices/modules/efivars
  - Missing efivars may block NVRAM writes; systemd-boot may still install if configured

Future improvements (ideas)
- Add automated tests for installers (VM-based integration tests)
- Optional disko-based installers
- More desktop profiles or a flag to include a DE in the installed system
- More robust TUI with validations and dry-run modes

License & contributions
- Apache-2.0. See top-level LICENSE (Spanish translation provided but non-authoritative).
- Contributions via issues/PRs are welcome.

