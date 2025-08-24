# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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

