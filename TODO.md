English | [Español](./TODO.es.md)

# TODO (Install/Rescue ISO Enhancements)

Rescue Experience

- [ ] Add a guided rescue-menu.sh for common tasks:
  - [ ] Mount and chroot into installed NixOS (bind mounts + nixos-enter)
  - [ ] Reinstall systemd-boot and regenerate EFI entries
  - [ ] Btrfs: list/create/rollback snapshots (@ and @home)
  - [ ] Disk health: SMART/NVMe health, badblocks quick tests
  - [ ] Imaging: ddrescue wizard (source, dest, mapfile)
- [ ] Provide snapper default configs for root and home (optional opt-in script)
- [ ] Helper wrapper to activate btrfsmaintenance timers (if desired)

Installer Improvements

- [x] Add optional scripts to create mirroring on boot drive where supported
- [ ] Add optional swapfile creation on Btrfs (with correct NOCOW/compression
      settings)
- [ ] Allow choosing disk encryption (LUKS on Btrfs) flow
- [ ] Optional separate /var or additional subvolumes presets
- [x] Option to set hashed passwords non-interactively (prompt -> openssl -6) —
      Implemented in all installer scripts when openssl is available

Security & Access

- [ ] Live ISO: switch SSH to key-only mode toggle (env var or flag)
- [ ] Add simple firewall presets for rescue vs. install contexts

Docs & UX

- [ ] scripts/README: add examples for rescue tasks (chroot, boot repair,
      ddrescue)
- [ ] README.md: document scripts/build-iso.sh usage and profiles
- [ ] Tools-Included.md: keep in sync when toolset changes (ongoing)

CI/CD

- [ ] Add CI job to build nixos-recovery ISO artifact on pushes to the branch
- [x] Add flake checks in CI (nix flake check) — Implemented via
      .github/workflows/check-flake.yml

Filesystem Coverage

- [ ] Ensure complete tooling and live support for major filesystems:
  - [x] EXT4: e2fsprogs (fsck.ext4, resize2fs, tune2fs, etc.) — included in live
        ISO and installer
  - [x] XFS: xfsprogs (xfs_repair, xfs_growfs, etc.) — included in live ISO and
        installer
  - [x] Bcachefs: bcachefs-tools — included in live ISO and installer
  - [x] ZFS: userland tools (zfs, zpool) and kernel module availability on the
        live ISO (align with boot.zfs.package) — userland sourced from
        config.boot.zfs.package; kernel/package aligned in common.nix; installer
        exists
- [ ] Verify mounting/repair workflows from the live ISO and document in
      HOWTO/Tools-Included
- [x] Consider adding cifs-utils for SMB/CIFS mounts (in addition to nfs-utils)
      — included (also added nfs-utils)
