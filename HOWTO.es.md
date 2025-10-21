<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./HOWTO.md) | Español

# Repositorio Nix-ISO de un vistazo

Este repositorio construye ISOs personalizadas de instalación de NixOS (unstable) con tres perfiles:
- Minimal (nixos-minimal)
- GNOME (nixos-gnome)
- COSMIC (nixos-cosmic)

Cómo está conectado
- flake.nix define tres nixosConfigurations, cada una importando un módulo de perfil más el conjunto de herramientas de recuperación compartido:
  - minimal/default.nix importa el módulo del instalador minimal + common.nix + recovery/recovery-tools.nix
  - gnome/default.nix importa los módulos del instalador de GNOME + common.nix + recovery/recovery-tools.nix
  - cosmic/default.nix importa cosmic/cosmic.nix + common.nix + recovery/recovery-tools.nix
- common.nix se comparte entre perfiles. Este:
  - importa el módulo chaotic nyx
  - habilita flakes/nix-command y unfree
  - overlay de bcachefs-tools desde el repositorio upstream
  - cambia al kernel CachyOS y la variante de ZFS
  - habilita muchos sistemas de archivos
  - instala herramientas base (vim, git, curl, parted, efibootmgr)

Dónde añadir paquetes
- Global (todas las ISOs): common.nix -> environment.systemPackages
- Por perfil: <profile>/default.nix -> environment.systemPackages
  - Ejemplo (minimal/default.nix):
    environment.systemPackages = with pkgs; [ gnused gawk neovim coreutils git curl pciutils btrfs-progs ];

Añadir scripts complejos (sin infierno de escapes)
- Coloca tus scripts en un directorio scripts/ en el repositorio, como archivos planos.
- Empácalos con una pequeña derivación y añádelos a environment.systemPackages.
  Ejemplo de módulo overlay:

  {
    pkgs, lib, ...
  }:
  let
    myTools = pkgs.stdenv.mkDerivation {
      pname = "iso-tools";
      version = "1.0";
      src = ./scripts; # directorio con tus scripts
      installPhase = ''
        mkdir -p $out/bin
        # instalar sin escapes; mantiene tus scripts originales intactos
        cp -r $src/* $out/bin/
        chmod -R +x $out/bin
      '';
    };
  in {
    environment.systemPackages = [ myTools ];
  }

- Coloca configuraciones vía environment.etc si es necesario:
  environment.etc."myapp/config.toml".text = ''
    # tu configuración
  '';

Notas y advertencias
- Todos los perfiles incluyen por defecto el conjunto completo de herramientas de recuperación vía recovery/recovery-tools.nix.
- El repositorio obtiene kernel/ZFS de chaotic nyx; verifica los cachés en nixConfig de flake.nix.
- README usa NIXPKGS_ALLOW_BROKEN=1; si las compilaciones fallan, prueba sin él o fija inputs.
- El perfil COSMIC inicia sesión automáticamente con el usuario "nixos" en el ISO en vivo.

CI
- .github/workflows compila la ISO minimal y publica artefactos en GitHub.

Prerrequisitos del host (cachés binarios)
Para asegurar compilaciones rápidas, configura los ajustes de Nix de tu host para confiar en los cachés binarios usados por este flake.

NixOS (recomendado)
Añade a /etc/nixos/configuration.nix y aplica con sudo nixos-rebuild switch:

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

No NixOS (demonio multiusuario)
Edita /etc/nix/nix.conf y reinicia nix-daemon:

accept-flake-config = true
substituters = https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/
trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8=

No NixOS (usuario único)
Edita ~/.config/nix/nix.conf con los mismos ajustes anteriores.

Flags de compilación de una sola ejecución
Añade a tu comando de compilación:
--accept-flake-config \
--option substituters "https://cache.nixos.org https://nix-community.cachix.org https://nyx.chaotic.cx/" \
--option trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="

Comandos de compilación
- Minimal: env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
- GNOME:   env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-gnome.config.system.build.isoImage --impure
- COSMIC:  env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-cosmic.config.system.build.isoImage --impure

Todos los perfiles incluyen el conjunto de herramientas de recuperación por defecto.

Siguientes pasos (si quieres que lo implemente ahora)
- Añadir herramientas solicitadas globalmente en common.nix (gnused, gawk, neovim, coreutils, git, curl, pciutils, btrfs-progs)
- Crear scripts/ con tus scripts complejos; añadir el módulo de empaquetado para que se incluyan en el ISO
- Opcional: añadir entradas environment.etc para configuraciones que quieras presentes en el ISO

