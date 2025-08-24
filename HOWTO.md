# Nix-ISO HOWTO

This guide explains how to build and use the custom NixOS ISOs in this repo, with a focus on the new recovery ISO that includes an installer and a comprehensive toolset.

Profiles
- Minimal (nixos-minimal)
- GNOME (nixos-gnome)
- COSMIC (nixos-cosmic)
- Recovery (nixos-recovery) — recommended for install and rescue workflows

Build the ISO (simple)
- Use the wrapper script (sets env and prints friendly messages):
  - ./scripts/build-iso.sh nixos-recovery
  - Defaults to nixos-recovery if you omit the argument
- Output appears in ./result/iso/

Build the ISO (manual)
- env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-recovery.config.system.build.isoImage --impure

What’s in the Recovery ISO
- All core install and rescue tools, categorized in Tools-Included.md
- sshd enabled in the live environment for remote assistance (password auth allowed on live ISO)
- Packaged scripts in $PATH (see scripts/), including an interactive Btrfs installer:
  - install-btrfs.sh: guided Btrfs install with subvolumes (@, @home, @nix, @snapshots)

Use the Recovery ISO to install NixOS
1) Boot the ISO
2) (Optional) SSH in as nixos user (passwordless by default) or work locally
3) Run the installer:
   - sudo install-btrfs.sh
   - It will prompt you for timezone, keymap, hostname, username
   - It will list disks, ask you to pick one, and require typing INSTALL to confirm
   - It partitions (ESP 1 GiB + Btrfs), creates subvolumes, mounts with zstd+discard, generates configs, writes a safe configuration.nix, then runs nixos-install (you will be prompted to set root password)
4) Reboot into your installed system

Rescue with the Recovery ISO
- Disk health: smartctl, nvme-cli, hdparm, lshw
- Imaging: ddrescue, pv
- Filesystem repair: btrfs-progs, e2fsprogs, xfsprogs, ntfs3g, exfatprogs, dosfstools
- Encryption/RAID/LVM: cryptsetup, mdadm, lvm2
- Snapshots/backups: snapper, btrbk, grub-btrfs, btrfsmaintenance
- Bootloader tools: efibootmgr (and grub-btrfs integration)
- Network tools: ssh, curl, wget, rsync, iproute2/iputils

Where to add packages
- Global (all ISOs): common.nix -> environment.systemPackages
- Per-profile: <profile>/default.nix -> environment.systemPackages

Add complex scripts (without escaping)
- Put scripts in scripts/ and they are packaged automatically on the recovery ISO
- See scripts/README.md for installer usage; future scripts can be added similarly

Notes & Gotchas
- Chaotic nyx module supplies the CachyOS kernel and ZFS; trust/caches configured in flake.nix
- Flakes and nix-command enabled; unfree allowed in common.nix
- The installer’s generated configuration uses sudo wheelNeedsPassword = true and does not grant passwordless sudo

CI
- Existing workflows build minimal ISO; add a job to build nixos-recovery in CI as a future task (see TODO.md)

