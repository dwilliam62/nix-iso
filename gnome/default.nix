# This is a basic NixOS configuration template for a live ISO image
# that can be used to install NixOS on a system.
# ISO can be built using `nix build .#nixosConfigurations.nixos-iso.config.system.build.isoImage`
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
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ../common.nix
    ../recovery/recovery-tools.nix
  ];

  networking.hostName = "nixos-gnome"; # set live session hostname

  # Enable NetworkManager to manage network connections.
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true; # enables support for Bluetooth

  # Include Desktop Icons NG extension; attribute name varies across nixpkgs snapshots.
  # Prefer desktop-icons-ng; fall back to ding if needed.
  environment.systemPackages = let
    dingExt = if pkgs.gnomeExtensions ? desktop-icons-ng then pkgs.gnomeExtensions.desktop-icons-ng
              else if pkgs.gnomeExtensions ? ding then pkgs.gnomeExtensions.ding
              else null;
  in with pkgs; [
    gparted
    google-chrome
  ] ++ lib.optionals (dingExt != null) [ dingExt ];

  # Enable Desktop Icons NG and basic desktop icons via dconf (NixOS: programs.dconf)
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/shell" = {
            enabled-extensions = [ "ding@rastersoft.com" ];
          };
          "org/gnome/shell/extensions/ding" = {
            show-home = true;
            show-trash = true;
          };
        };
      }
    ];
  };

  # Customize ISO filename to distinguish from standard NixOS ISOs
  image.fileName = lib.mkForce "nixos-ddubsos-gnome-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
  #isoImage.isoName = lib.mkForce "nixos-ddubsos-gnome-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
}
