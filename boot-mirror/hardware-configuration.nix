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
