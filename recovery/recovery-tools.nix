# Recovery tooling and live ISO conveniences shared by all profiles
{
  config,
  lib,
  pkgs,
  ...
}:
let
  nixIsoDocs = pkgs.stdenv.mkDerivation {
    pname = "nix-iso-docs";
    version = "1.0";
    src = ../.;
    dontBuild = true;
    installPhase = ''
      set -euo pipefail
      dst="$out/share/nix-iso-docs"
      mkdir -p "$dst"
      # Copy top-level docs if present
      for f in README.md README.es.md HOWTO.md Tools-Included.md; do
        if [ -f "$src/$f" ]; then cp "$src/$f" "$dst/"; fi
      done
      # Convert Markdown to HTML for offline viewing (README and README.es if present)
      if [ -f "$src/README.md" ]; then
        "${pkgs.pandoc}/bin/pandoc" -s -o "$dst/README.html" "$src/README.md"
      fi
      if [ -f "$src/README.es.md" ]; then
        "${pkgs.pandoc}/bin/pandoc" -s -o "$dst/README.es.html" "$src/README.es.md"
      fi
      # Copy docs tree if present
      if [ -d "$src/docs" ]; then
        cp -r "$src/docs" "$dst/docs"
      fi
      # Include scripts README if present
      if [ -f "$src/scripts/README.md" ]; then
        mkdir -p "$dst/scripts"
        cp "$src/scripts/README.md" "$dst/scripts/"
      fi
    '';
  };
in
{
  # Network and convenience services for live environments
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # Enable SSH server on the live ISO for remote recovery work
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes"; # convenience for recovery; change after install
      PasswordAuthentication = true; # allow passwords on live media
    };
  };

  # Package the repository scripts into PATH on the live ISO
  environment.systemPackages =
    with pkgs;
    let
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

    in
    [
      recoveryScripts
      nixIsoDocs

      # Core CLI
      coreutils
      gnused
      gawk
      gnugrep
      findutils
      ripgrep
      ugrep
      which
      file
      util-linux
      busybox
      sudo

      # Editors
      neovim
      vim
      nano

      # Networking/transfer
      curl
      wget
      rsync
      openssh
      iproute2
      iputils
      mtr
      traceroute
      nmap
      socat
      netcat-openbsd
      jq
      yq-go
      openssl

      # Storage/filesystems & recovery
      parted
      gptfdisk
      efibootmgr
      btrfs-progs
      e2fsprogs
      xfsprogs
      bcachefs-tools
      ntfs3g
      exfatprogs
      dosfstools
      nfs-utils
      cifs-utils
      cryptsetup
      lvm2
      mdadm
      smartmontools
      hdparm
      nvme-cli
      ddrescue
      testdisk
      timeshift
      zstd
      xz
      bzip2
      gzip
      zip
      unzip
      pv

      # Documentation generator/viewer
      pandoc

      # ZFS userland (zpool, zfs) — align with kernel/module package
      # Use the configured boot.zfs.package to ensure compatibility

    ]
    ++ [ config.boot.zfs.package ]
    # Btrfs snapshot/backup tooling (CLI)
    ++ [
      snapper
      btrbk
    ]
    # Hardware utils and monitors
    ++ [
      pciutils
      usbutils
      lshw
      lsof
      strace
      gdb
      htop
      btop
      atop
    ];

  # Expose docs on the live ISO for quick reference
  environment.etc."nix-iso-docs".source = "${nixIsoDocs}/share/nix-iso-docs";

  # Desktop and launcher entries for documentation (offline HTML and online link)
  # Desktop icons for new users (live user inherits from skel)
  environment.etc."skel/Desktop/nix-iso-docs.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nix-iso Documentation
    Comment=Open the nix-iso documentation folder
    Exec=xdg-open /etc/nix-iso-docs
    Icon=folder-documents
    Terminal=false
    Categories=Documentation;Utility;
  '';
  environment.etc."skel/Desktop/nix-iso-readme-en.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nix-iso README (EN)
    Comment=Open the nix-iso README in your browser (offline HTML)
    Exec=xdg-open /etc/nix-iso-docs/README.html
    Icon=text-html
    Terminal=false
    Categories=Documentation;Utility;
  '';
  environment.etc."skel/Desktop/nix-iso-readme-es.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nix-iso README (ES)
    Comment=Abrir el README de nix-iso en el navegador (HTML sin conexión)
    Exec=xdg-open /etc/nix-iso-docs/README.es.html
    Icon=text-html
    Terminal=false
    Categories=Documentation;Utility;
  '';
  environment.etc."skel/Desktop/nix-iso-readme-online.desktop".text = ''
    [Desktop Entry]
    Type=Link
    Name=nix-iso README (Online)
    URL=https://gitlab.com/dwilliam62/nix-iso
    Icon=web-browser
  '';

  # App grid entries (system-wide)
  environment.etc."xdg/applications/nix-iso-docs.desktop".text =
    config.environment.etc."skel/Desktop/nix-iso-docs.desktop".text;
  environment.etc."xdg/applications/nix-iso-readme-en.desktop".text =
    config.environment.etc."skel/Desktop/nix-iso-readme-en.desktop".text;
  environment.etc."xdg/applications/nix-iso-readme-es.desktop".text =
    config.environment.etc."skel/Desktop/nix-iso-readme-es.desktop".text;
  environment.etc."xdg/applications/nix-iso-readme-online.desktop".text =
    config.environment.etc."skel/Desktop/nix-iso-readme-online.desktop".text;

  # Ensure the live user's Desktop has these icons (copy from skel at boot)
  # This targets the standard live user 'nixos' provided by installation media.
  systemd.tmpfiles.rules = [
    "d /home/nixos/Desktop 0755 nixos users -"
    "C /home/nixos/Desktop/nix-iso-docs.desktop 0644 nixos users - /etc/skel/Desktop/nix-iso-docs.desktop"
    "C /home/nixos/Desktop/nix-iso-readme-en.desktop 0644 nixos users - /etc/skel/Desktop/nix-iso-readme-en.desktop"
    "C /home/nixos/Desktop/nix-iso-readme-es.desktop 0644 nixos users - /etc/skel/Desktop/nix-iso-readme-es.desktop"
    "C /home/nixos/Desktop/nix-iso-readme-online.desktop 0644 nixos users - /etc/skel/Desktop/nix-iso-readme-online.desktop"
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
        curl wget pciutils btrfs-progs openssl
        htop btop atop
      ];

      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      system.stateVersion = "25.11";
    }
  '';
}
