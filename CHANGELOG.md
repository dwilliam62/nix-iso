# Changelog

All notable changes to this project will be documented in this file.

## [2026-09-29] ddubsos-iso

- Fixed `zaneyos-main.sh` syntax error
- ZaneyOS installers: fix post-install ownership of `~/zaneyos` (`scripts/install-zaneyos-main.sh`, `scripts/install-zaneyos.sh`)
  - The previous chroot-based fix failed with `chown: command not found`, because inside a chroot the NixOS tools live in `/run/current-system/sw/bin`, which is not on the default `PATH`; `~/zaneyos` was left owned by `root`
  - Resolve the target user's UID/GID from `/mnt/etc/passwd` and run `chown -R` from the live system against `/mnt/home/<user>/zaneyos` (same proven approach as `install-hyprland-btw.sh`); the fallback hint is still printed if the UID/GID cannot be determined
- Flake inputs: drop the unused `chaotic` (chaotic-nyx) input and its binary cache
  - `common.nix` no longer imports the chaotic nyx module, so the input was dead weight
  - Removed `https://chaotic-nyx.cachix.org/` and its public key from `nixConfig`; `https://nix-community.cachix.org/` is kept
  - Regenerated `flake.lock` (removed `chaotic`, `chaotic/flake-schemas`, `chaotic/home-manager`, `chaotic/home-manager/nixpkgs`, `chaotic/nixpkgs`; deduped `nixpkgs_2` into `nixpkgs`, same revision)
- Add ZRAM swap to `common.nix` (`zramSwap.enable = true`, `memoryPercent = 200`)
- hyprland-btw installer: harden against a corrupt upstream `flake.lock` (`scripts/install-hyprland-btw.sh`)
  - Validate `flake.lock` before `nix flake update`; if it is missing, contains Git conflict markers, or is invalid JSON, remove it so Nix regenerates a clean lock
  - Fixes an install abort (`json.exception.parse_error.101 ... expected string literal`) when the cloned repo ships a lock with committed merge-conflict markers
  - Companion fix: repaired `dwilliam62/hyprland-btw` `main` (resolved the `flake.lock` conflict markers; commit 2f35446)
- CI: disable all GitHub Actions workflows (this branch builds ISOs locally; no CI is desired)
  - Renamed every workflow to a non-`.yml` extension so GitHub ignores it: `update-flake-lock.yml.disabled`, `check-flake.yml.disabled`, `build-and-release.yml.disabled`
  - Note: a `DISABLE.`/`DISABLED.` filename prefix does NOT disable a workflow; GitHub runs any `*.yml`/`*.yaml` under `.github/workflows/`, so the previous renames had no effect. `update-flake-lock` auto-committed `flake.lock` (weekly schedule + `push` on `flake.nix`) and `check-flake` ran `nix flake check` on every push/PR
- ddubsos install (`scripts/install-ddubsos.sh`): pick and pin a GPU/profile per host
  - Detect a VM (`systemd-detect-virt`) and pin the new host to `profile = "vm"` (GPU drivers disabled); on bare metal, prompt for a GPU profile (blank keeps the flake default)
  - New `set_host_var` helper sets/replaces an attribute in `hosts/<host>/variables.nix`, inserting before the final closing brace only (the old `sddmWaylandEnable` append matched every brace-only line, e.g. nested list braces)
  - Companion change in `dwilliams62/ddubsos` `flake.nix`: `hostProfileOverride` reads `profile` from `hosts/<host>/variables.nix`, overriding the flake-level default (previously `nvidia-laptop`)
  - Fixes ddubsos install failure building `nvidia-open-595.45.04` for `linux-7.2.8` (`linux/of_gpio.h: No such file or directory`); ddubsos commits `012d273d`
- Repair `dwilliams62/ddubsos` `flake.lock` (resolved committed merge-conflict markers; commit `7c3644ee`)
  - The lock shipped with 20 unresolved 3-way conflict blocks, making it invalid JSON and aborting `nixos-install` (`json.exception.parse_error.101 ... expected string literal`)
  - Resolved to the newer "Updated flake" side; validated with `nix flake lock` and `nix eval .#nixosConfigurations`
- Update flake for nix-iso project
  - Now uses NixOS v26.11

## [2025-12-26] ddubsos-iso

- ZaneyOS-next new host wasn't owned by user

## [2025-12-24] ddubsos-iso

- Set ddubsos-iso branchd as default in GitHub
- Added install options for:
  - ZaneyOS - main branch
  - ZaneyOS - zos-next branch (testing)

## [2005-10] ddubsos-iso

- Breaking: Remove ZFS and bcachefs features from ISOs and tools
  - Drop ZFS and bcachefs from boot.supportedFilesystems; stop packaging bcachefs-tools and ZFS userland in recovery tools
  - Remove ZFS/bcachefs installers from the TUI menu and from packaged scripts on the ISO
  - Remove bcachefs overlay wiring
- Kernel: switch to nixpkgs' latest kernel (boot.kernelPackages = linuxPackages_latest) instead of CachyOS
- TUI UX: make "Install scripts" the first menu section and "Documentation and links" second
- Dev UX: make nix fmt format only tracked .nix files to avoid hangs on large/untracked trees
- Flake inputs: update to latest with `nix flake update`
- Fix: rename services.vmwareGuest to virtualisation.vmware.guest to address evaluation warning
- GNOME ISO: replace Home Manager-style `dconf.settings` with NixOS `programs.dconf` to fix evaluation error
- GNOME ISO: enable Desktop Icons NG (ding) and show Home/Trash icons; make extension package selection resilient across nixpkgs (desktop-icons-ng or ding)
- GNOME ISO: mark Desktop .desktop entries as executable so they appear and can be launched without extra steps
- GNOME ISO: enable user extensions via dconf so Desktop Icons NG can surface icons reliably (Desktop directory created via tmpfiles is used)
- TUI: add modular terminal menu (scripts/nix-iso) with sections:
  - Install scripts (bcachefs marked "EXPERIMENTAL - Use at own risk"; mirror installers marked "Testing - not for production use")
  - Documentation and links (offline HTML and GitHub repo)
- COSMIC ISO: Desktop launcher now uses a wrapper that opens a terminal explicitly and runs nix-iso; deduplicate icons with OnlyShowIn/NotShowIn so only one shows on COSMIC
- Minimal ISO: print login hint "To access menu -- run nix-iso" after auto-login; also show this hint when opening a terminal in GNOME/COSMIC

## [2025-08-28] ddubsos-iso

- Docs: Add a comprehensive project guide consolidating overview, architecture, build/install flows, filesystem defaults, and TUI usage
  - English: docs/project-guide.md
  - Español: docs/project-guide.es.md
  - Link both from README.md under Documentation and add language-switch links at the top of the guides
- Docs: Add a deep-dive section covering scripts/install-\*.sh behavior and guardrails for quick AI/human onboarding
- Docs: Document profile-specific UX and docs packaging across ISO profiles
  - Offline docs generated via pandoc to HTML and installed under /etc/nix-iso-docs
  - Desktop/app menu entries to open docs and launch the installer TUI (nix-iso)
  - Minimal ISO: console help banner prints "To access menu -- run nix-iso" after auto-login
  - COSMIC ISO: COSMIC-specific launcher that opens a terminal and runs nix-iso
  - GNOME ISO: launchers/icons configured but not functioning as expected as of 2025-08-28; users can run nix-iso from a terminal
- README: Add links to the new project guides (EN/ES) in the Documentation section

## [2025-08-27] ddubsos-iso

- Docs UX: Add offline HTML rendering for README (EN/ES) using pandoc during ISO build
  - Generate /etc/nix-iso-docs/README.html and README.es.html
  - Keep Markdown sources and docs/ tree under /etc/nix-iso-docs
- Desktop integration: Add .desktop entries for quick access to documentation
  - Desktop icons (via /etc/skel/Desktop) and app grid entries (via /etc/xdg/applications)
  - nix-iso Documentation opens /etc/nix-iso-docs
  - nix-iso README (EN/ES) open offline HTML in the browser
  - nix-iso README (Online) links to GitLab project page
- Rename docs path on live ISO from /etc/ddubsos-docs to /etc/nix-iso-docs
- VM guest services: enable guest daemons; systemd starts them only inside VMs
  - GNOME ISO: enable Desktop Icons NG (ding) so Desktop .desktop entries are visible by default
  - services.qemuGuest.enable = true
  - services.spice-vdagentd.enable = true (SPICE clipboard/display integration)
  - virtualisation.vmware.guest.enable = true
  - VirtualBox guest skipped to avoid conflicting definition with installation ISO base module; can be enabled per-profile with mkForce if needed
  - Hyper-V skipped: option not available on current nixpkgs snapshot; will re-enable when present

## [2025-08-26] ddubsos-iso

- bcachefs installer (scripts/install-bcachefs.sh):
  - Add user-facing note at destructive confirmation explaining that messages like "ERROR: not a btrfs filesystem: /mnt/..." are benign probes from btrfs tools during config/mount inspection and can be safely ignored when installing to bcachefs.
  - Generate hardware-configuration.nix with --no-filesystems and explicitly declare bcachefs subvolume mounts in configuration.nix to avoid incorrect auto-detection.
  - Add udevadm settle after mkfs.bcachefs to ensure by-uuid symlinks exist before mounting.
  - Mount helper now tries both subvolume= and subvol= options for broader compatibility.
- mirror installers (scripts/install-zfs-boot-mirror.sh, scripts/install-btrfs-boot-mirror.sh):
  - Fix DISK1/2 unbound variable under set -u by avoiding subshell in selection parsing.
  - Change parse_selection to return status and set DISK1/DISK2 in the current shell; expose PARSE_ERR for detailed messages.
  - Gate use of boot.loader.systemd-boot.mirroredBoots so installs work on older nixpkgs snapshots that lack the option.
    - First via lib.mkIf, then via lib.optionalAttrs to avoid defining nonexistent options, and finally checking presence through config to prevent module arg cycles.
    - When the option is absent, the install proceeds without auto-replicating /boot -> /boot2; ZFS/Btrfs mirrors are unaffected.
  - Warning: the mirror installers are experimental and not intended for production use. Use at your own risk.
  - Commit references: 87630c1, 478b44c, da551f7, de5a415

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
    - Remove btrfs-only mount options (compress=) from bcachefs mounts; use only noatime; rename subvolumes to simple names (root, home, nix, var, var-\*) and bind from a staging mount.

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
