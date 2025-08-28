<!--
Author: Don Williams (aka ddubs)
Created: 2025-08-27
Project: https://github.com/dwilliam62/nix-iso
-->

# Plan: One-step installer ISOs for zaneyos (25.05) and ddubsos (25.11)

Goal
- Produce two separate live ISOs using the existing nix-iso framework that perform a one-step install of fully configured systems:
  - zaneyos: NixOS 25.05 stable, Hyprland-focused
  - ddubsos: NixOS 25.11 unstable, expanded apps and desktops
- Keep the live ISO minimal; the installer scripts will fetch or copy the project flake and run nixos-install --flake for a single-step installation.

Repositories / inputs
- nix-iso (this repo): base ISO framework, recovery tools, TUI, docs
- zaneyos: ~/zaneyos (flake exposing nixosConfigurations for target systems)
- ddubsos: ~/ddubsos (flake exposing nixosConfigurations for target systems)

Approaches
1) Project-aware installers (recommended)
   - Add scripts/install-zaneyos.sh and scripts/install-ddubsos.sh modeled on existing install-*.sh.
   - Flow:
     1. Partition and mount target (GPT: 1GiB ESP + remainder FS; reuse current guardrails and flow).
     2. Generate hardware-configuration.nix via nixos-generate-config --root /mnt.
     3. Provide the project flake under /mnt/etc/nixos (clone over network OR copy embedded repo).
     4. Place hardware-configuration.nix where the project expects it OR inject it via an overlay module.
     5. Run nixos-install --root /mnt --flake /mnt/etc/nixos#<target>.
   - Pros: Compatible with different channels; installed system pins its own flake. Minimal changes to nix-iso.
   - Cons: Requires the projects to expose appropriate nixosConfigurations and accept generated hardware config.

2) Embed projects into the ISO (offline-capable)
   - Package ~/zaneyos and ~/ddubsos into the ISO (derivations in recovery/recovery-tools.nix) under e.g. /share/nix-iso-projects/{zaneyos,ddubsos}.
   - Installer copies from store path to /mnt/etc/nixos.
   - Pros: Works without network; truly one-step.
   - Cons: Rebuild ISO whenever the project changes (or allow optional git pull if network exists).

3) Per-project ISO profiles
   - Create profiles nixos-zaneyos and nixos-ddubsos that include embedded projects and project-specific installers and docs entries.
   - Pros: Super clear UX—each ISO is dedicated to one project.
   - Cons: More profiles to maintain (acceptable given current structure).

Recommended path
- Implement Approach 1 first, with optional embedding from Approach 2 for offline installs.
- Keep one ISO family per project if desired later (Approach 3) by adding profiles.

Installer script design (both zaneyos and ddubsos)
- Base: copy set -euo pipefail, root/sudo, PATH hygiene, dependency checks, destructive confirmation, disk selection, GPT layout, and mounting from your existing installers.
- Steps:
  1. Disk selection, wipe, partition (ESP + data), mkfs, mount (FS specifics can remain ext4/XFS/Btrfs/ZFS depending on preference; simplest is ext4 or Btrfs for these project installers).
  2. nixos-generate-config --root /mnt (use --no-filesystems if you prefer to declare explicit mounts later).
  3. Acquire project flake:
     - Online: git clone https://<repo> /mnt/etc/nixos (or ssh/https depending on environment).
     - Offline: cp -a /nix/store/<project-symlink>/ /mnt/etc/nixos (if embedded).
  4. Hardware config handling options:
     - Drop-in: keep /mnt/etc/nixos/hardware-configuration.nix and have the project import it (recommended simplicity).
     - Overlay injection: write a small module next to the project flake that imports the generated hardware-configuration.nix and any user selections (timezone, keymap, username) so the project remains unchanged.
  5. nixos-install --root /mnt --flake /mnt/etc/nixos#<target> (host/system attribute exposed by the project flake).
  6. Post-install message; optional reboot prompt.

Hardware-configuration.nix: two patterns
- Drop-in import (preferred): project flake should import ./hardware-configuration.nix as part of its modules for the target host/system.
- Overlay module: installer writes a local module (e.g., overlay.nix) that imports both the project’s module and /mnt/etc/nixos/hardware-configuration.nix, and passes any installer choices (user/timezone/keymap). Then install with --flake "/mnt/etc/nixos?dir=./#<target>" plus -I or from a composite temp flake.

Channels and compatibility
- Live ISO channel can differ from installed system channel. nixos-install --flake uses the project’s pinned nixpkgs.
- For best fidelity, we can optionally build a zaneyos ISO against 25.05 and a ddubsos ISO against 25.11, but it’s not required.

TUI integration
- Add menu entries:
  - Install zaneyos (one-step)
  - Install ddubsos (one-step)
- Flags:
  - --source=embedded|git (choose from embedded copy on ISO or clone online)
  - --target=<flakeAttr> (select host/system attribute to install)

Docs and UX
- Include relevant project README snippets in /etc/nix-iso-docs (pandoc HTML + Markdown) for both ISOs.
- Keep the minimal ISO console hint and graphical launchers; add project-specific quickstart pages if helpful.

Security and guardrails
- Reuse all current safeguards: container warning, UEFI efivars note, mounted FS checks, ZFS module checks (if using ZFS), explicit INSTALL confirmation.
- Do not echo secrets; hash user passwords with openssl -6 if prompting for them.

Risks / considerations
- If project structure expects a specific path for hardware-configuration.nix, ensure the installer moves or references it correctly.
- MirroredBoots: only enable when available in nixpkgs to avoid evaluation issues.
- Rebuilding ISO needed when embedding project sources.
- Network access variability: provide both offline and online modes.

Next steps checklist
- Confirm each project’s flake outputs (which nixosConfigurations to install by default) and whether they will import a local ./hardware-configuration.nix.
- Decide FS choice for these project installers (ext4/XFS for simplicity or Btrfs with subvols).
- Implement two installers: scripts/install-zaneyos.sh and scripts/install-ddubsos.sh (clone/copy + nixos-install --flake).
- Optionally embed ~/zaneyos and ~/ddubsos into the ISO and add a --source flag in installers.
- Update TUI to add the new entries and docs to reference the one-step flow.
- Consider separate ISO profiles for each project after the scripts are validated.

