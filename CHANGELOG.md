# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [2025-08-26] ddubsos-iso
- bcachefs installer (scripts/install-bcachefs.sh):
  - Add user-facing note at destructive confirmation explaining that messages like "ERROR: not a btrfs filesystem: /mnt/..." are benign probes from btrfs tools during config/mount inspection and can be safely ignored when installing to bcachefs.
  - Generate hardware-configuration.nix with --no-filesystems and explicitly declare bcachefs subvolume mounts in configuration.nix to avoid incorrect auto-detection.
  - Add udevadm settle after mkfs.bcachefs to ensure by-uuid symlinks exist before mounting.
  - Mount helper now tries both subvolume= and subvol= options for broader compatibility.
- mirror installers (scripts/install-zfs-boot-mirror.sh, scripts/install-btrfs-boot-mirror.sh):
  - Fix DISK1/2 unbound variable under set -u by avoiding subshell in selection parsing.
  - Change parse_selection to return status and set DISK1/DISK2 in the current shell; expose PARSE_ERR for detailed messages.
  - Commit: "mirror installers: fix DISK1/2 unbound var by avoiding subshell; use return status + PARSE_ERR" (87630c1)

## [2025-08-25] ddubsos-iso
- ZFS installers: adopt a practical dataset layout similar to btrfs @-style subvolumes using ZFS datasets.
- bcachefs installer: adopt structured subvolume layout and initrd support.
  - scripts/install-bcachefs.sh
    - Create subvolumes: @ (root), @home, @nix, @var, @var_log, @var_cache, @var_tmp, @var_lib.
    - Mount with compress=zstd,noatime; apply nodev,noexec on log/cache/tmp.
    - Add boot.initrd.supportedFilesystems = [ "bcachefs" ]; to generated configuration.
    - Add guardrails: explicit EXPERIMENT acknowledgement and kernel support check (modprobe + /proc/filesystems).
  - scripts/install-zfs.sh
    - Add guardrails: environment warnings; refuse if any ZFS filesystems are mounted or pools imported; verify ZFS module available.
    - Harden mounted/imported checks to avoid false positives; print detected mounts/pools when refusing.
    - Create a container dataset rpool/root (mountpoint=none) and an actual root rpool/root/nixos (mounted at /).
    - Split /var into dedicated datasets with tuned properties:
      - rpool/var (mountpoint=none)
      - rpool/var/log (exec=off, devices=off)
      - rpool/var/cache (exec=off, devices=off, com.sun:auto-snapshot=false)
      - rpool/var/tmp (exec=off, devices=off, com.sun:auto-snapshot=false)
      - rpool/var/lib
    - Keep separate datasets: rpool/home and rpool/nix (atime=off) for compression and snapshot control.
    - Update mount sequence accordingly; remove the previous rpool/snapshots dataset and /.snapshots mount.
  - scripts/install-zfs-boot-mirror.sh
    - Add guardrails: environment warnings; refuse if any ZFS filesystems are mounted or pools imported; verify ZFS module available.
    - Harden mounted/imported checks to avoid false positives; print detected mounts/pools when refusing.
    - New installer that provisions a ZFS mirror capable of booting.
    - Interactively selects two unmounted disks, validates sizes, shows destructive prompt.
    - Partitions both disks (ESP + ZFS), creates mirrored pool, mounts both ESPs at /boot and /boot2.
    - Configures systemd-boot mirroredBoots for the second ESP; includes ZFS initrd support and hostId.
    - Uses the same practical dataset layout as install-zfs.sh.
  - scripts/install-btrfs-boot-mirror.sh
    - Add guardrails: environment warnings; refuse if any btrfs filesystems are mounted.
    - Harden btrfs mounted check to avoid false positives; print detected mounts.
    - New installer that provisions a Btrfs mirrored (RAID1) root capable of booting.
    - Interactively selects two unmounted disks with destructive confirmation.
    - Partitions both disks (ESP + Btrfs), creates a Btrfs filesystem with -m raid1 -d raid1.
    - Creates subvolumes (@, @home, @nix, @snapshots) and mounts with compress=zstd,discard=async,noatime.
    - Mounts both ESPs at /boot and /boot2 and configures systemd-boot.mirroredBoots for replication.
  - scripts/install-btrfs.sh
    - Harden btrfs mounted check to avoid false positives; print detected mounts.
  - scripts/install-bcachefs.sh
    - Harden bcachefs mounted check to avoid false positives; print detected mounts.
    - Ensure PATH includes common sbin locations; add missing runtime requires.
    - Fix parted error: remove unsupported fs-type token from mkpart (bcachefs); name the partition; format with mkfs.bcachefs.
    - Further suppress helper noise by mounting top-level and bind-mounting subvolumes (no subvol mount options); remount nodev/noexec on log/cache/tmp.
    - Remove btrfs-only mount options (compress=) from bcachefs mounts; use only noatime; rename subvolumes to simple names (root, home, nix, var, var-*) and bind from a staging mount.

- Shell/Terminals: Add tmux with system-wide /etc/tmux.conf (simple, broadly compatible)
  - Provide sane defaults: prefix C-a, mouse on, vi keys, base-index 1, pane-base-index 1
  - Set status bar at top, 24-bit color override, default-terminal screen-256color
  - Directional pane movement, splits preserve working dir, basic zoom/reload utilities
  - Avoid popups/menus and terminal-specific features for ISO compatibility

Future considerations
- Snapshots/retention management: enable services.sanoid or services.zfs.autoSnapshot with sensible policies; mark noisy datasets as non-snapshotted.
- Native ZFS encryption for selected datasets (or full root), including initrd key management.
- Workload tuning datasets and properties for databases (recordsize=16K), VMs/large files (recordsize=1M, logbias=throughput), and Docker under /var/lib/docker.
- Boot environments (e.g., zedenv) to pair ZFS datasets with NixOS generations for rollback workflows.
- Swap strategy: prefer a swap partition; if using zvol-backed swap, apply safe properties and exclude from snapshots.

## [2025-08-24] ddubsos-iso
- Add ai-summary.json: machine-readable summary for AI processing.
- Add HUMAN_SUMMARY.md: concise human-friendly overview and extension guidance.
- Document extension points for adding packages, scripts, and configs to the ISO builds.
- Live ISO: include full filesystem tooling for rescue/recovery use-cases:
  - Add NFS and SMB/CIFS mount tooling (nfs-utils, cifs-utils)
  - Include ZFS userland (zpool, zfs) by sourcing from config.boot.zfs.package for kernel compatibility
  - Ensure ext4/xfs/btrfs/bcachefs tool coverage in all profiles
- Docs: update Tools-Included.md to reflect new filesystem tools and ZFS userland
- Docs: update TODO.md and mark completed items (hashed password support in installers; CI flake checks; CIFS/NFS; ZFS userland)
- Docs: README rewrite with upstream credits, install/recovery overview, and included tooling
- Docs: README formatting fix for installer example (use fenced code block)
- Docs: Prefer scripts/build-iso.sh helper for building ISOs; keep manual nix build commands as advanced fallback

