# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [2025-08-25] ddubsos-iso
- ZFS installers: adopt a practical dataset layout similar to btrfs @-style subvolumes using ZFS datasets.
- bcachefs installer: adopt structured subvolume layout and initrd support.
  - scripts/install-bcachefs.sh
    - Create subvolumes: @ (root), @home, @nix, @var, @var_log, @var_cache, @var_tmp, @var_lib.
    - Mount with compress=zstd,noatime; apply nodev,noexec on log/cache/tmp.
    - Add boot.initrd.supportedFilesystems = [ "bcachefs" ]; to generated configuration.
    - Add guardrails: explicit EXPERIMENT acknowledgement and kernel support check (modprobe + /proc/filesystems).
  - scripts/install-zfs.sh
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
    - New installer that provisions a ZFS mirror capable of booting.
    - Interactively selects two unmounted disks, validates sizes, shows destructive prompt.
    - Partitions both disks (ESP + ZFS), creates mirrored pool, mounts both ESPs at /boot and /boot2.
    - Configures systemd-boot mirroredBoots for the second ESP; includes ZFS initrd support and hostId.
    - Uses the same practical dataset layout as install-zfs.sh.
  - scripts/install-btrfs-boot-mirror.sh
    - New installer that provisions a Btrfs mirrored (RAID1) root capable of booting.
    - Interactively selects two unmounted disks with destructive confirmation.
    - Partitions both disks (ESP + Btrfs), creates a Btrfs filesystem with -m raid1 -d raid1.
    - Creates subvolumes (@, @home, @nix, @snapshots) and mounts with compress=zstd,discard=async,noatime.
    - Mounts both ESPs at /boot and /boot2 and configures systemd-boot.mirroredBoots for replication.

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

