# Guide: Converting systemd-boot to Mirrored GRUB

1. Prepare the Secondary EFI Partition
   - Btrfs handles the data mirror, but it doesn't touch the EFI partitions.
   - You must manually ensure the second partition exists and is formatted.

Identify UUIDs: Use `lsblk -f` to find the UUIDs of your two VFAT partitions (e.g., 0C60-CCDC and 0C61-7F7C).

Format if needed: Ensure the second partition is FAT32.

```Bash
sudo mkfs.vfat -F 32 -n EFI_B /dev/sdX1
2. Configure Mount Points (hardware-configuration.nix)
You must define two distinct mount points. Using a name like /boot2 is standard. Crucially, use the nofail flag so the system boots even if one drive is missing.
```

```Nix
fileSystems."/boot" = {
  device = "/dev/disk/by-uuid/0C60-CCDC";
  fsType = "vfat";
  options = [ "fmask=0022" "dmask=0022" "nofail" ];
};

fileSystems."/boot2" = {
  device = "/dev/disk/by-uuid/0C61-7F7C";
  fsType = "vfat";
  options = [ "fmask=0022" "dmask=0022" "nofail" ];
};
3. Transition the Bootloader (configuration.nix)
Disable systemd-boot and enable grub with the mirroredBoots attribute. This is the "magic" step that tells NixOS to run the installation script twice.
```

```Nix
boot.loader = {
  systemd-boot.enable = false; # Explicitly disable the old loader
  efi.canTouchEfiVariables = true;
  grub = {
    enable = true;
    device = "nodev"; # Required for EFI
    efiSupport = true;
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
```

4. Critical Syntax & Path Matching
   Path Alignment: The path defined in mirroredBoots must match the mount point defined in fileSystems exactly.

UUID Verification: Verify that the devices list in mirroredBoots matches the device UUID in your file systems. If they are swapped, GRUB will fail the "EFI partition check."

5. Execution
   If you are changing the `NIX_PATH` or working in a custom shell like Zsh, it is often safer to explicitly point to your config file during the first run:

```Bash
sudo nixos-rebuild boot
> Note: If you can an error about `nix-build` not found try this:
sudo nixos-rebuild boot -I nixos-config=/etc/nixos/configuration.nix
```

> Redundancy: By having two independent EFI partitions, you can lose either virtual disk in Proxmox and still hit a boot menu.

Btrfs Awareness: GRUB is significantly better at handling advanced Btrfs setups (like subvolumes and snapshots) than the more minimal systemd-boot.

6. Example

- `Configuration.nix`

```nix

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

```

- `hardware-configuration.nix`

```nix

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # --- Btrfs Mirror (RAID1) Configuration ---
  # Using UUID ensures the mirror mounts even if /dev/sda fails
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/ef8c5c09-a94b-4e58-91c6-b1a3ebe0bf51";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/ef8c5c09-a94b-4e58-91c6-b1a3ebe0bf51";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/ef8c5c09-a94b-4e58-91c6-b1a3ebe0bf51";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/.snapshots" =
    { device = "/dev/disk/by-uuid/ef8c5c09-a94b-4e58-91c6-b1a3ebe0bf51";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd" ];
    };

  # --- Mirrored EFI Partitions ---
  # Added 'nofail' so the VM boots even if one virtual disk is missing
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/0C60-CCDC";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" "nofail" ];
    };

  fileSystems."/boot2" =
    { device = "/dev/disk/by-uuid/0C61-7F7C";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" "nofail" ];
    };


  fileSystems."/mnt/nas" =
    { device = "192.168.40.11:/volume1/DiskStation54TB";
      fsType = "nfs";
      options = [ "rw" "bg" "tcp" "_netdev" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

```
