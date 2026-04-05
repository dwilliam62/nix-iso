{ pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # --- Bootloader (GRUB Mirrored Setup) ---
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev"; # Required for EFI systems
        efiSupport = true;
        # Matches your lsblk: EFI_A (0C60-CCDC) and EFI_B (0C61-7F7C)
        mirroredBoots = [
          {
            path = "/boot";
            devices = [ "/dev/disk/by-uuid/0C60-CCDC" ]; 
          }
          {
            path = "/boot2";
            devices = [ "/dev/disk/by-uuid/0C61-7F7C" ];
          }
        ];
      };
    };

    # Kernel Modules and Zswap Tuning
    kernelModules = [ "z3fold" ];
    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=20"
      "zswap.zpool=z3fold"
    ];         
  };

  # --- Networking ---
  networking = {
    hostName = "zos-next-mirror";
    networkmanager.enable = true;
    firewall.enable = false; # Disabled as per your previous config
  };             
               
  # --- System Localization ---
  time.timeZone = "America/New_York";
  console.keyMap = "us";
            
  # --- User Configuration ---
  users.users.dwilliams = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" ];
    # Ensure your hashed password line is placed here
  };             
               
  # --- System Packages ---
  environment.systemPackages = with pkgs; [
    git ncftp htop btop pciutils btrfs-progs wget curl
    neovim gnused gawk ripgrep gnugrep findutils coreutils
    tmux luarocks python3 yazi shared-mime-info
  ];             
               
  # --- Programs ---
  programs = { 
    mtr.enable = true;
    neovim = { 
      enable = true;
      defaultEditor = true;
    };       
  };             
               
  # --- Services ---
  services = { 
     openssh.enable = true;
     qemuGuest.enable = true;
     # Spice-vdagentd is explicitly omitted to prevent resizing issues
  };          

  # --- Nix Package Manager Settings ---
  nixpkgs.config.allowUnfree = true;
               
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    accept-flake-config = true;
  };             
               
  # --- Security ---
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };             
               
  # --- State Version ---
  # Reflecting your upgrade target of 25.11
  system.stateVersion = "25.11";
}

