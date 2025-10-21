{
  description = "Unstable NixOS custom installation media";

  # Main sources and repositories
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable"; # Unstable NixOS system (default)
    bcachefs-tools = {
      url = "github:koverstreet/bcachefs-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Don't add follows nixpkgs, else will cause local rebuilds
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # Bleeding edge packages from chaotic nyx, especially CachyOS kernel
  };

  outputs =
    {
      self,
      nixpkgs,
      chaotic,
      ...
    }@inputs:
    let
      system = "x86_64-linux"; # change arch here

      specialArgs = {
        inherit inputs;
      };
    in
    {
      formatter.${system} =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "nix-iso-fmt";
          runtimeInputs = [
            pkgs.git
            pkgs.nixfmt-rfc-style
            pkgs.findutils
            pkgs.gnugrep
            pkgs.coreutils
          ];
          text = ''
            set -euo pipefail
            # Format only tracked .nix files to avoid traversing large/untracked trees
            fmt_one() {
              local f="$1"
              [ -f "$f" ] || return 0
              local tmp
              tmp=$(mktemp)
              if cat "$f" | nixfmt -f "$f" >"$tmp"; then
                mv "$tmp" "$f"
              else
                rm -f "$tmp"
                echo "nixfmt failed on: $f" >&2
                return 1
              fi
            }
            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
              git ls-files -z -- '*.nix' 2>/dev/null | while IFS= read -r -d $'\0' f; do fmt_one "$f"; done
            else
              # Fallback: find *.nix in cwd
              find . -type f -name '*.nix' -print0 2>/dev/null | while IFS= read -r -d $'\0' f; do fmt_one "$f"; done
            fi
          '';
        };

      ## GNOME ISO ##
      nixosConfigurations.nixos-gnome = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./gnome
        ];
        inherit specialArgs;
      };

      ## COSMIC ISO ##
      nixosConfigurations.nixos-cosmic = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./cosmic
        ];
        inherit specialArgs;
      };

      ## MINIMAL ISO ##
      nixosConfigurations.nixos-minimal = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./minimal
        ];
        inherit specialArgs;
      };

      ## RECOVERY ISO ##
      nixosConfigurations.nixos-recovery = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./recovery
        ];
        inherit specialArgs;
      };
    };

  # Allows the user to use our cache when using `nix run <thisFlake>`.
  nixConfig = {
    extra-substituters = [
      "https://nyx.chaotic.cx/"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
