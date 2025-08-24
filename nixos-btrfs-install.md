NixOS Btrfs Install Playbook (Remote/Live USB, Non-Interactive)

This playbook reproduces the successful installation flow we used, designed for
remote installs from a live USB, with robust, non-interactive commands and tool
bootstrapping.

Principles • Use non-interactive commands to avoid losing SSH sessions (no
interactive nix-shell or editors). • Bootstrap needed tools ad hoc with
nix-shell --run wrappers. • Prefer complete file writes (heredocs) over brittle
inline edits. • Use absolute paths, disable pagers/aliases, and avoid history
expansion pitfalls.

Tool Bundle (on-demand) Bring common CLI tools as needed without leaving your
session: nix-shell -p\
coreutils gnused gawk gnugrep findutils util-linux\
parted dosfstools btrfs-progs e2fsprogs\
iproute2 iputils openssh openssl rsync\
neovim git curl wget pciutils usbutils nfs-utils jq ripgrep tmux\
--run 'bash -lc "echo tools ready"'

Notes: • coreutils gives real cat, tee, nl. Use command cat to bypass aliases
like bat. • nfs-utils provides the NFS client. neovim is optional; prefer
scripted edits.

Steps

0. Identify Target Disk (safety) nix-shell -p coreutils util-linux --run 'bash
   -lc " lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL echo; echo
   /dev/disk/by-id: ls -l /dev/disk/by-id "' Confirm the target device (e.g.,
   /dev/sda vs /dev/nvme0n1).

1. Partition: GPT, 1024 MiB ESP + rest Btrfs nix-shell -p util-linux parted
   --run 'bash -lc " set -euxo pipefail TARGET=/dev/sda wipefs -af "$TARGET"
parted -s "$TARGET" mklabel gpt parted -s
   "$TARGET" mkpart ESP fat32 1MiB 1025MiB
parted -s "$TARGET" set 1 esp on parted -s "$TARGET" mkpart primary btrfs
   1025MiB 100% "'

2. Filesystems nix-shell -p dosfstools btrfs-progs --run 'bash -lc " set -euxo
   pipefail mkfs.fat -F32 -n EFI /dev/sda1 mkfs.btrfs -f -L nixos /dev/sda2 "'

3. Create Btrfs Subvolumes (@, @home, @nix) nix-shell -p btrfs-progs coreutils
   --run 'bash -lc " set -euxo pipefail mkdir -p /mnt mount -o subvolid=5
   /dev/sda2 /mnt btrfs subvolume create /mnt/@ btrfs subvolume create
   /mnt/@home btrfs subvolume create /mnt/@nix btrfs subvolume list /mnt umount
   /mnt "'

4. Mount Subvolumes (compress=zstd, discard=async, noatime) nix-shell -p
   btrfs-progs coreutils dosfstools --run 'bash -lc " set -euxo pipefail mount
   -o compress=zstd,discard=async,noatime,subvol=@ /dev/sda2 /mnt mkdir -p
   /mnt/{home,nix,boot} mount -o
   compress=zstd,discard=async,noatime,subvol=@home /dev/sda2 /mnt/home mount -o
   compress=zstd,discard=async,noatime,subvol=@nix /dev/sda2 /mnt/nix mount
   /dev/sda1 /mnt/boot mount | grep -E "^/dev/(sd|nvme)" "'

5. Generate Base Config nix-shell -p nixos-install-tools --run 'bash -lc "
   nixos-generate-config --root /mnt "'

6. Add NFS mount to hardware-configuration.nix nix-shell -p gnused coreutils
   --run 'bash -lc " set -euo pipefail
   HC=/mnt/etc/nixos/hardware-configuration.nix mkdir -p /mnt/nas grep -Fq
   "fileSystems.\"/mnt/nas\"" "$HC" || tee -a "$HC" >/dev/null <<'NIXEOF'

NFS mount fileSystems."/mnt/nas" = { device =
"192.168.40.11:/volume1/DiskStation54TB"; fsType = "nfs"; options = [ "rw" "bg"
"intr" "soft" "tcp" "_netdev" ]; }; NIXEOF "'

7. Write configuration.nix (one-shot) Includes UEFI boot, hostname, user,
   packages, OpenSSH, NFS client, and zswap via kernelParams (works across
   25.05). nix-shell -p coreutils --run 'bash -lc " set -euo pipefail tee
   /mnt/etc/nixos/configuration.nix >/dev/null <<'NIXCONF' { pkgs, ... }:

{ imports = [ ./hardware-configuration.nix ];

boot = { loader = { systemd-boot.enable = true; efi.canTouchEfiVariables = true;
}; kernelModules = [ "z3fold" ]; kernelParams = [ "zswap.enabled=1"
"zswap.compressor=zstd" "zswap.max_pool_percent=20" "zswap.zpool=z3fold" ]; };

networking = { hostName = "pegasus"; networkmanager.enable = true;
firewall.enable = false; extraHosts = '' 192.168.40.11 nas ''; };

time.timeZone = "America/New_York";

users.users.dwilliams = { hashedPassword =
"$6$3t5xe9kHB9tTWDG0$gi3VcM.pXsl6dcmjP70OdNw1i4X/tbhe2yXm1DzqBlJ1Ep7vAUnq/UWrqTxkxxFGSiBmO8rm7kW1Jty/TjYPO/";
isNormalUser = true; extraGroups = [ "input" "wheel" ]; packages = with pkgs; [
atop ]; };

environment.systemPackages = with pkgs; [ git ncftp htop btop pciutils
btrfs-progs wget curl ];

programs = { mtr.enable = true; neovim = { enable = true; defaultEditor = true;
}; };

services = { openssh.enable = true; nfs.client.enable = true; # client for NAS
rpcbind.enable = true; };

nixpkgs.config.allowUnfree = true; nix.settings.experimental-features = [
"nix-command" "flakes" ];

security.sudo = { enable = true; wheelNeedsPassword = true; };

system.stateVersion = "25.05"; } NIXCONF "'

8. Install (interactive root password prompt) nixos-install Follow the prompt to
   set the root password.

9. Reboot and Verify mount | grep -E '^/dev/(sd|nvme)|:/volume1/DiskStation54TB'
   systemctl status remote-fs.target cat /sys/module/zswap/parameters/enabled
   cat /sys/module/zswap/parameters/compressor cat
   /sys/module/zswap/parameters/max_pool_percent cat
   /sys/module/zswap/parameters/zpool

Pitfalls and Remedies • Missing tools: always wrap with nix-shell -p ... --run
'bash -lc "..."' to avoid interactive shells. • Aliases (cat->bat): use command
cat or rely on tee/sed -n. • Zsh history expansion: prefer bash -lc or set +H. •
boot.zswap not available: use boot.kernelParams + boot.kernelModules approach
for zswap. • Btrfs top-level: mount subvolid=5 to create/list subvolumes. •
NVIDIA Werror on linux-zen: switch to mainline kernelPackages or proprietary
driver if needed; avoid Werror if patching.

Optional • Non-interactive root password (hash): nix-shell -p openssl --run
'bash -lc "read -rsp "root password: " P; echo; printf %s "$P" | openssl passwd
-6 -stdin"' Then add to configuration.nix:
users.users.root.initialHashedPassword = "<hash>"; EOF
