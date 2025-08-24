# Recovery/Install ISO profile with extensive tooling and a starter configuration.nix
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    # Base minimal installer and channel so /etc/nixos exists and nixos-install works
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ../common.nix
  ];

  networking.hostName = "nixos-recovery"; # live session hostname
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # Enable SSH server on the live ISO for remote work
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";           # convenience for recovery; change after install
      PasswordAuthentication = true;      # allow passwords on live media
    };
  };

  # Broad tooling for install/recovery workflows
  environment.systemPackages = with pkgs; [
    # Core CLI
    coreutils gnused gawk gnugrep findutils ripgrep ugrep which file
    util-linux busybox

    # Editors
    neovim vim nano

    # Networking/transfer
    curl wget rsync openssh iproute2 iputils mtr traceroute nmap socat netcat-openbsd
    jq yq-go

    # Storage/filesystems & recovery
    parted gptfdisk efibootmgr
    btrfs-progs e2fsprogs xfsprogs
    bcachefs-tools
    ntfs3g exfatprogs dosfstools
    cryptsetup lvm2 mdadm
    smartmontools hdparm nvme-cli
    gddrescue testdisk
    zstd xz bzip2 gzip zip unzip pv

    # Hardware utils
    pciutils usbutils lshw lsof strace gdb
  ];

  # Place a starter configuration at /etc/nixos/configuration.nix on the live ISO
  # so users (or automation) can edit and run `nixos-install` quickly.
  environment.etc."nixos/configuration.nix".text = ''
    { pkgs, ... }:
    {
      imports = [ ./hardware-configuration.nix ];

      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        # Cross-channel zswap configuration using kernel params
        kernelModules = [ "z3fold" ];
        kernelParams = [
          "zswap.enabled=1"
          "zswap.compressor=zstd"
          "zswap.max_pool_percent=20"
          "zswap.zpool=z3fold"
        ];
      };

      # Basic system identity — edit these before install
      networking.hostName = "changeme";
      networking.networkmanager.enable = true;
      time.timeZone = "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      # Users — default credentials for initial access; change after install
      users.users.root.initialPassword = "NixOS_rulez!";
      users.users.dwilliams = {
        isNormalUser = true;
        initialPassword = "NixOS_rulez!";
        extraGroups = [ "wheel" "networkmanager" "input" ];
      };

      # Package policy and tooling
      nixpkgs.config.allowUnfree = true;
      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # Remote access on the installed system (optional — keep if desired)
      services.openssh.enable = true;

      # Handy tools inside the installed system as well (trim as needed)
      environment.systemPackages = with pkgs; [
        neovim vim gnused gawk ripgrep gnugrep findutils coreutils
        curl wget pciutils btrfs-progs
      ];

      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      system.stateVersion = "25.05";
    }
  '';
}
