{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.chaotic.nixosModules.default
  ];

  nixpkgs.config.allowUnfree = true;
  # Set environment variable for allowing non-free packages
  environment.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ]; # enable nix command and flakes

  nixpkgs.overlays = [
    (final: prev: {
      bcachefs-tools = inputs.bcachefs-tools.packages.${pkgs.system}.bcachefs-tools;
    })
    # Work around upstream breakage: pygls tests fail with lsprotocol API mismatch on python3.13
    (final: prev: {
      python3Packages = prev.python3Packages.overrideScope (pyFinal: pyPrev: {
        pygls = pyPrev.pygls.overrideAttrs (old: {
          doCheck = false;               # skip pytest phase
          pytestCheckPhase = ''true'';   # no-op safeguard
        });
        i3ipc = pyPrev.i3ipc.overrideAttrs (old: {
          doCheck = false;               # async tests failing under pytest/python 3.13
          pytestCheckPhase = ''true'';   # no-op safeguard
        });
      });
    })
  ];

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  boot.zfs.package = lib.mkOverride 99 pkgs.zfs_cachyos;
  boot.supportedFilesystems = [
    "btrfs"
    "vfat"
    "f2fs"
    "xfs"
    "ntfs"
    "cifs"
    "bcachefs"
    "ext4"
    "zfs"
  ];

  environment.systemPackages = with pkgs; [
    # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    vim
    git
    curl
    parted
    efibootmgr
  ];

  # Wireless network and wired network is enabled by default
}
