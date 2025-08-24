# Recovery tooling and live ISO conveniences shared by all profiles
{ config, lib, pkgs, ... }:
{
  # Network and convenience services for live environments
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # Enable SSH server on the live ISO for remote recovery work
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";      # convenience for recovery; change after install
      PasswordAuthentication = true; # allow passwords on live media
    };
  };

  # Package the repository scripts into PATH on the live ISO
  environment.systemPackages = with pkgs; let
    recoveryScripts = pkgs.stdenv.mkDerivation {
      pname = "recovery-scripts";
      version = "1.0";
      src = ../scripts;
      dontBuild = true;
      installPhase = ''
        mkdir -p "$out/bin"
        cp -r "$src"/* "$out/bin/" || true
        chmod -R +x "$out/bin" || true
      '';
    };
  in [
    recoveryScripts

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
    ddrescue testdisk
    zstd xz bzip2 gzip zip unzip pv

    # Btrfs snapshot/backup tooling (CLI)
    snapper btrbk btrfsmaintenance

    # Hardware utils
    pciutils usbutils lshw lsof strace gdb
  ];

  # Provide a starter configuration at /etc/nixos/configuration.nix
  # so users can quickly edit and run nixos-install.
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

