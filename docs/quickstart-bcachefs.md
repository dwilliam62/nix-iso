# Quickstart: bcachefs installer (experimental)

Use this when experimenting with bcachefs on a single disk. Not recommended for production.

Prerequisites
- UEFI firmware (systemd-boot is used)
- Running as root (sudo is fine)
- Kernel supports bcachefs (module or built-in)
- No bcachefs filesystems mounted

Steps
1) Run the installer
```bash
./scripts/install-bcachefs.sh
```
2) Follow prompts
- You must type EXPERIMENT to acknowledge the risks
- Timezone, keymap, hostname, username (and password if OpenSSL is available)
- Select the target disk
- Confirm destructive action by typing INSTALL
3) What the script does
- Partitions the disk: 1 GiB ESP (FAT32), rest bcachefs
- Creates subvolumes: @ → /, @home → /home, @nix → /nix, @var* for var splits
- Mounts with compress=zstd,noatime; ESP at /mnt/boot
- Writes configuration.nix with boot.supportedFilesystems and initrd support
- Runs nixos-install
4) Reboot into your experimental system

Guardrails
- Requires explicit EXPERIMENT acknowledgement
- Verifies kernel support via /proc/filesystems and modprobe
- Refuses if any bcachefs filesystems are mounted
- Warns on containerized environments and missing UEFI efivars

