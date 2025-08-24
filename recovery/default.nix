# Recovery/Install ISO profile that reuses the shared recovery toolset
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    # Base minimal installer and channel so /etc/nixos exists and nixos-install works
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ../common.nix
    ./recovery-tools.nix
  ];

  networking.hostName = "nixos-recovery"; # live session hostname

  # Customize ISO filename to distinguish from standard NixOS ISOs
  image.fileName = "nixos-ddubsos-recovery-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.isoName = lib.mkForce "nixos-ddubsos-recovery-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
}
