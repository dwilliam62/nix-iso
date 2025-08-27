# This is a basic NixOS configuration template for a live minimal ISO image
# that can be used to install NixOS on a system.
# ISO can be built using `nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage`
# Make sure to enable flakes and nix-command on the host system before building the ISO
# Resulting image can be found in ./result/iso/ directory
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ../common.nix
    ../recovery/recovery-tools.nix
  ];

  networking.hostName = "nixos-minimal"; # set live session hostname

  # Show a hint after auto-login on console
  environment.loginShellInit = ''
    printf "\nTo access menu -- run nix-iso\n\n"
  '';

  # Customize ISO filename to distinguish from standard NixOS ISOs
  image.fileName = lib.mkForce "nixos-ddubsos-minimal-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
  #isoImage.isoName = lib.mkForce "nixos-ddubsos-minimal-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
}
