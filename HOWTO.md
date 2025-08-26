English | [Español](./HOWTO.es.md)

# Nix-ISO repo at a glance

This repo builds custom NixOS installation ISOs (unstable) with three profiles:
- Minimal (nixos-minimal)
- GNOME (nixos-gnome)
- COSMIC (nixos-cosmic)

How it’s wired
- flake.nix defines three nixosConfigurations, each importing a profile module plus the shared recovery toolset:
  - minimal/default.nix imports the minimal installer module + common.nix + recovery/recovery-tools.nix
  - gnome/default.nix imports the GNOME installer modules + common.nix + recovery/recovery-tools.nix
  - cosmic/default.nix imports cosmic/cosmic.nix + common.nix + recovery/recovery-tools.nix
- common.nix is shared across profiles. It:
  - imports the chaotic nyx module
  - enables flakes/nix-command and unfree
  - overlays bcachefs-tools from the upstream repo
  - switches to the CachyOS kernel and ZFS variant
  - enables many filesystems
  - installs base tools (vim, git, curl, parted, efibootmgr)

Where to add packages
- Global (all ISOs): common.nix -> environment.systemPackages
- Per-profile: <profile>/default.nix -> environment.systemPackages
  - Example (minimal/default.nix):
    environment.systemPackages = with pkgs; [ gnused gawk neovim coreutils git curl pciutils btrfs-progs ];

Adding complex scripts (without escaping hell)
- Put your scripts in a scripts/ directory in the repo, as plain files.
- Package them with a small derivation and add to environment.systemPackages.
  Example overlay module:

  {
    pkgs, lib, ...
  }:
  let
    myTools = pkgs.stdenv.mkDerivation {
      pname = "iso-tools";
      version = "1.0";
      src = ./scripts; # directory with your scripts
      installPhase = ''
        mkdir -p $out/bin
        # install without escaping; keeps your original scripts intact
        cp -r $src/* $out/bin/
        chmod -R +x $out/bin
      '';
    };
  in {
    environment.systemPackages = [ myTools ];
  }

- Place configs via environment.etc if needed:
  environment.etc."myapp/config.toml".text = ''
    # your config
  '';

Notes and gotchas
- All profiles include the full recovery toolset by default via recovery/recovery-tools.nix.
- The repo pulls kernel/ZFS from chaotic nyx; verify caches in flake.nix’s nixConfig.
- README uses NIXPKGS_ALLOW_BROKEN=1; if builds fail, try without it or pin inputs.
- COSMIC profile autologins user "nixos" on the live ISO.

CI
- .github/workflows builds minimal ISO and publishes artifacts on GitHub.

Host prerequisites (binary caches)
To ensure fast builds, configure your host’s Nix settings to trust the binary caches used by this flake.

NixOS (recommended)
Add to /etc/nixos/configuration.nix and apply with sudo nixos-rebuild switch:

nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  accept-flake-config = true;
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://nyx.chaotic.cx/"
  ];
  trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
  ];
};

Non-NixOS (multi-user daemon)
Edit /etc/nix/nix.conf and restart nix-daemon:

accept-flake-config = true
substituters = https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/
trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=

Non-NixOS (single-user)
Edit ~/.config/nix/nix.conf with the same settings as above.

One-shot build flags
Add to your build command:
--accept-flake-config \
--option substituters "https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/" \
--option trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="

Build commands
- Minimal: env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
- GNOME:   env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-gnome.config.system.build.isoImage --impure
- COSMIC:  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-cosmic.config.system.build.isoImage --impure

All profiles include the recovery toolset by default.

Next steps (if you want me to implement now)
- Add requested tools globally in common.nix (gnused, gawk, neovim, coreutils, git, curl, pciutils, btrfs-progs)
- Create scripts/ with your complex scripts; add the packaging module so they land in the ISO
- Optional: add environment.etc entries for configs you want present on the ISO

