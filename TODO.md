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
- [ ] Add optional swapfile creation on Btrfs (with correct NOCOW/compression settings)
- [ ] Allow choosing disk encryption (LUKS on Btrfs) flow
- [ ] Optional separate /var or additional subvolumes presets
- [ ] Option to set hashed passwords non-interactively (prompt -> openssl -6)

Security & Access
- [ ] Live ISO: switch SSH to key-only mode toggle (env var or flag)
- [ ] Add simple firewall presets for rescue vs. install contexts

Docs & UX
- [ ] scripts/README: add examples for rescue tasks (chroot, boot repair, ddrescue)
- [ ] README.md: document scripts/build-iso.sh usage and profiles
- [ ] Tools-Included.md: keep in sync when toolset changes

CI/CD
- [ ] Add CI job to build nixos-recovery ISO artifact on pushes to the branch
- [ ] Add flake checks for recovery profile (nix flake check)
