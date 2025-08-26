[English](./nixos-btrfs-install.md) | Español

# Manual de instalación de NixOS con Btrfs (no interactivo)

Este manual refleja lo que hacen los instaladores interactivos de Btrfs, usando comandos robustos y no interactivos.
También destaca la configuración de arranque en espejo cuando hay dos discos disponibles.

Principios
- Usar comandos no interactivos para evitar perder sesiones SSH.
- Aprovisionar herramientas con envoltorios nix-shell --run.
- Preferir escrituras completas de archivos (heredocs) en lugar de ediciones en línea.
- Usar rutas absolutas y deshabilitar paginadores/alias.

Conjunto de herramientas (bajo demanda)
Trae herramientas comunes de CLI según sea necesario sin salir de tu sesión:

```bash
nix-shell -p \
  coreutils gnused gawk gnugrep findutils util-linux \
  parted dosfstools btrfs-progs e2fsprogs \
  iproute2 iputils openssh openssl rsync \
  neovim git curl wget pciutils usbutils nfs-utils jq ripgrep tmux \
  --run 'bash -lc "echo tools ready"'
```

Notas
- coreutils provee cat real, tee, nl; usa command cat para evitar alias como bat.
- nfs-utils proporciona el cliente NFS. neovim es opcional; preferir ediciones por script.

Pasos

0. Identificar el disco de destino (seguridad) nix-shell -p coreutils util-linux --run 'bash
   -lc " lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL echo; echo
   /dev/disk/by-id: ls -l /dev/disk/by-id "' Confirma el dispositivo de destino (p. ej.,
   /dev/sda vs /dev/nvme0n1).

1. Particionar: GPT, 1024 MiB ESP + resto Btrfs nix-shell -p util-linux parted
   --run 'bash -lc " set -euxo pipefail TARGET=/dev/sda wipefs -af "$TARGET"
parted -s "$TARGET" mklabel gpt parted -s
   "$TARGET" mkpart ESP fat32 1MiB 1025MiB
parted -s "$TARGET" set 1 esp on parted -s "$TARGET" mkpart primary btrfs
   1025MiB 100% "'

2. Sistemas de archivos nix-shell -p dosfstools btrfs-progs --run 'bash -lc " set -euxo
   pipefail mkfs.fat -F32 -n EFI /dev/sda1 mkfs.btrfs -f -L nixos /dev/sda2 "'

3. Crear subvolúmenes Btrfs (@, @home, @nix, opcionalmente @snapshots)
   nix-shell -p btrfs-progs coreutils --run 'bash -lc " set -euxo pipefail \
   mkdir -p /mnt; mount -o subvolid=5 /dev/sda2 /mnt; \
   btrfs subvolume create /mnt/@; \
   btrfs subvolume create /mnt/@home; \
   btrfs subvolume create /mnt/@nix; \
   btrfs subvolume create /mnt/@snapshots; \
   umount /mnt "'

4. Montar subvolúmenes (compress=zstd, discard=async, noatime)
   nix-shell -p btrfs-progs coreutils dosfstools --run 'bash -lc " set -euxo pipefail \
   mount -o compress=zstd,discard=async,noatime,subvol=@ /dev/sda2 /mnt; \
   mkdir -p /mnt/{home,nix,boot}; \
   mount -o compress=zstd,discard=async,noatime,subvol=@home /dev/sda2 /mnt/home; \
   mount -o compress=zstd,discard=async,noatime,subvol=@nix /dev/sda2 /mnt/nix; \
   mount /dev/sda1 /mnt/boot; \
   mount | grep -E "^/dev/(sd|nvme)" "'

5. Generar configuración base nix-shell -p nixos-install-tools --run 'bash -lc "
   nixos-generate-config --root /mnt "'

6. Añadir montaje NFS a hardware-configuration.nix nix-shell -p gnused coreutils
   --run 'bash -lc " set -euo pipefail
   HC=/mnt/etc/nixos/hardware-configuration.nix mkdir -p /mnt/nas grep -Fq
   "fileSystems.\"/mnt/nas\"" "$HC" || tee -a "$HC" >/dev/null <<'NIXEOF'

NFS mount fileSystems."/mnt/nas" = { device =
"192.168.40.11:/volume1/DiskStation54TB"; fsType = "nfs"; options = [ "rw" "bg"
"intr" "soft" "tcp" "_netdev" ]; }; NIXEOF "'

7. Escribir configuration.nix (de una vez) Incluye arranque UEFI, hostname, usuario,
   paquetes, OpenSSH, cliente NFS y zswap vía kernelParams (funciona en
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

system.stateVersion = "25.11";

8. Instalar (solicita contraseña de root de forma interactiva)
   nixos-install
   Sigue la indicación para establecer la contraseña de root.

9. Reiniciar y verificar
   mount | grep -E '^/dev/(sd|nvme)'
   systemctl status remote-fs.target
   cat /sys/module/zswap/parameters/enabled
   cat /sys/module/zswap/parameters/compressor
   cat /sys/module/zswap/parameters/max_pool_percent
   cat /sys/module/zswap/parameters/zpool

Escollos y soluciones • Falta de herramientas: siempre envuelve con nix-shell -p ... --run
'bash -lc "..."' para evitar shells interactivos. • Alias (cat->bat): usa command
cat o apóyate en tee/sed -n. • Expansión de historial en zsh: prefiere bash -lc o set +H. •
boot.zswap no disponible: usa boot.kernelParams + boot.kernelModules para
zswap. • Nivel superior de Btrfs: monta subvolid=5 para crear/listar subvolúmenes. •
Werror de NVIDIA en linux-zen: cambia a kernelPackages mainline o al controlador propietario
si es necesario; evita Werror si aplicas parches.

Opcional • Contraseña de root no interactiva (hash): nix-shell -p openssl --run
'bash -lc "read -rsp "root password: " P; echo; printf %s "$P" | openssl passwd
-6 -stdin"' Luego añade a configuration.nix:
users.users.root.initialHashedPassword = "<hash>"; EOF

