# This module defines a NixOS installation CD that contains Cosmic.

{ config, lib, pkgs, ... }:

{
  imports = [
    ./cosmic.nix
    ../common.nix
    ../recovery/recovery-tools.nix
  ];

  networking.hostName = "nixos-cosmic"; # set live session hostname

  # Enable NetworkManager to manage network connections.
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true; # enables support for Bluetooth

  environment.systemPackages = with pkgs; [
    gparted
    google-chrome
  ];

  # Customize ISO filename to distinguish from standard NixOS ISOs
  isoImage.isoName = "nixos-ddubsos-cosmic-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
}
