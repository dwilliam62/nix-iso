<!--
Author: Don Williams (aka ddubs)
Created: 2025-08-27
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./project-guide.md) | Español

# Guía del Proyecto — nix-iso: ISOs personalizadas de instalación/recuperación de NixOS

Propósito
- Construir ISOs en vivo de NixOS (minimal, GNOME, COSMIC, recovery) enfocadas en instalación y recuperación.
- Proveer scripts de instalación interactivos para múltiples sistemas de archivos (ZFS, Btrfs, XFS, ext4, bcachefs), más variantes experimentales con arranque espejado.
- Incluir un conjunto robusto de herramientas de recuperación y documentación sin conexión (offline) dentro de la ISO.

Inicio rápido
- Compilar con el helper:
  - Minimal: ./scripts/build-iso.sh minimal
  - GNOME: ./scripts/build-iso.sh gnome
  - COSMIC: ./scripts/build-iso.sh cosmic (experimental)
  - Recovery: ./scripts/build-iso.sh nixos-recovery
- Manual (ejemplo):
  - env NIXPKGS_ALLOW_BROKEN=1 nix build .#nixosConfigurations.nixos-minimal.config.system.build.isoImage --impure
- Arranca la ISO, abre una terminal y ejecuta: nix-iso (menú TUI de instalación y docs)
- Docs offline en el sistema en vivo: /etc/nix-iso-docs

Notas de seguridad
- Los scripts de instalación son destructivos para el disco objetivo seleccionado (reparticionan y formatean).
- Requieren escribir INSTALL para continuar.
- Lee cuidadosamente los prompts; verifica no estar en un contenedor y que las variables UEFI estén disponibles cuando sea necesario.

Estructura del repositorio (alto nivel)
- flake.nix — Define nixosConfigurations: nixos-minimal, nixos-gnome, nixos-cosmic, nixos-recovery. Usa nixpkgs inestable y el canal "chaotic nyx"; expone nixConfig con caches.
- common.nix — Configuración compartida:
  - allowUnfree, flakes habilitados, overlay de bcachefs-tools, overrides para pruebas python problemáticas
  - kernel: linuxPackages_cachyos; ZFS: zfs_cachyos; supportedFilesystems: btrfs, xfs, ext4, bcachefs, zfs, etc.
  - herramientas base y un /etc/tmux.conf amigable
- Perfiles
  - minimal/default.nix — Importa installation-cd-minimal.nix + common.nix + recovery/recovery-tools.nix
  - gnome/default.nix — ISO gráfica GNOME (installer base + channel.nix) + common + recovery-tools
  - cosmic/default.nix + cosmic/cosmic.nix — ISO de escritorio COSMIC (experimental)
  - recovery/default.nix — ISO de recuperación (channel + minimal) + recovery-tools
- recovery/recovery-tools.nix — Módulo clave:
  - Empaqueta scripts/ en el PATH de la ISO
  - Construye docs offline con pandoc (README.html / README.es.html) y copia docs/* a /etc/nix-iso-docs
  - Agrega accesos directos (.desktop) para abrir docs y lanzar el TUI
  - Activa NetworkManager y SSH; incluye un amplio set de herramientas de recuperación
- scripts/
  - build-iso.sh — Helper para nix build
  - install-*.sh — Instaladores interactivos por FS (btrfs, ext4, xfs, zfs, bcachefs) y variantes espejadas experimentales
  - nix-iso, nix-iso-run-in-terminal — Lanzadores TUI
  - tui/ — Módulos del TUI (docs, installers)
- docs/
  - filesystems-overview.md, filesystem-defaults.md, package-dependencies.md
  - quickstart-*.md: guías paso a paso por FS

Cómo se construyen los perfiles ISO
- Cada perfil importa el módulo instalador de NixOS adecuado (mínimo o gráfico) más channel.nix cuando corresponde.
- Todos importan common.nix y recovery/recovery-tools.nix (tooling de recuperación, TUI, docs offline).
- Los nombres de ISO se fuerzan a nixos-ddubsos-<perfil>-<versión>-<arqu>.iso.

Conjunto de herramientas incluido (resumen)
- Archivos: btrfs-progs, e2fsprogs, xfsprogs, bcachefs-tools, ntfs3g, exfatprogs, dosfstools, nfs-utils, cifs-utils
- Particionado/arranque: parted, gptfdisk, efibootmgr
- ZFS userland vía config.boot.zfs.package
- Recuperación/diagnóstico: ddrescue, testdisk, smartmontools, hdparm, nvme-cli, pciutils, usbutils
- CLI/UI: coreutils, busybox, ripgrep, (neo)vim, nano, tmux, curl, wget, rsync, jq, yq-go
- Snapshots/backups: snapper, btrbk
- Docs offline: HTML (pandoc) + Markdown en /etc/nix-iso-docs

Comportamiento del instalador (flujo común)
- Solicita timezone, keymap, hostname, usuario (hashea password con openssl -6 si está disponible)
- Selección de disco objetivo + confirmación INSTALL
- Particionado GPT: ESP de 1 GiB (FAT32) + resto para el FS
- Genera hardware-configuration.nix
- Escribe /etc/nixos/configuration.nix seguro (systemd-boot, zswap, NetworkManager, unfree, flakes)
- Ejecuta nixos-install (pide password de root)

Diseños por FS (resumen)
- ZFS: contenedor rpool/root + rpool/root/nixos → /; datasets para /home, /nix, /var/*; mountpoints legacy; genera networking.hostId
- Btrfs: @ → /, @home → /home, @nix → /nix, @snapshots → /.snapshots; variante espejada usa RAID1 y /boot, /boot2
- bcachefs (experimental): subvols root, home, nix, var*, compresión zstd
- ext4/XFS: diseños simples; activar services.fstrim.enable

Arranque espejado (scripts experimentales)
- Dos ESPs montadas en /boot y /boot2; boot.loader.systemd-boot.mirroredBoots cuando esté disponible
- ZFS/Btrfs: mirror vdev o RAID1 según corresponda; ejemplos comentados para mirroredBoots

Caches binarias
- Altamente recomendado para evitar compilar kernel/ZFS desde fuente al construir la ISO.
- Este flake expone extra-substituters y extra-trusted-public-keys (chaotic nyx, nix-community).

TUI y docs en la ISO en vivo
- TUI: nix-iso (también accesos en menús gráficos cuando corresponda)
- Docs: /etc/nix-iso-docs (Markdown y HTML)

UX específica por perfil y empaquetado de docs/iconos
- Común
  - recovery/recovery-tools.nix construye docs HTML con pandoc y copia docs/*.
  - Agrega accesos .desktop en el Escritorio del usuario en vivo y en el menú de apps para abrir docs y lanzar el TUI.
- Minimal
  - Banner de ayuda en consola: environment.loginShellInit muestra “To access menu -- run nix-iso”.
- COSMIC
  - Lanzador específico de COSMIC que abre una terminal y ejecuta nix-iso.
  - Accesos directos a docs en el Escritorio y el menú de apps.
- GNOME
  - Incluye Desktop Icons NG (ding) cuando existe y habilita iconos básicos vía dconf.
  - Pretende ofrecer los mismos accesos/launchers que otros perfiles.
  - Nota de estado (2025-08-28): La funcionalidad de iconos/launchers en GNOME está configurada pero actualmente no funciona como se espera. Los usuarios pueden abrir una terminal y ejecutar nix-iso.

Para IA y automatización (datos clave)
- Atributos de build: .#nixosConfigurations.<perfil>.config.system.build.isoImage
- Entradas críticas: flake.nix, common.nix, recovery/recovery-tools.nix, scripts/install-*.sh, scripts/build-iso.sh, scripts/nix-iso, docs/*
- Docs offline: /etc/nix-iso-docs
- Comando TUI: nix-iso

Análisis detallado: scripts install-*.sh
- Convenciones comunes: set -euo pipefail; root/sudo; PATH extendido; checks de dependencias; avisos de contenedor/UEFI; confirmación INSTALL; esquema GPT 1 GiB ESP; zswap con z3fold+zstd; base configuration.nix (NetworkManager, SSH, sudo, flakes, unfree, stateVersion=25.11).
- Variables de entorno: TIMEZONE, KEYMAP, HOSTNAME, USERNAME; en ZFS también POOL.
- Por script:
  - install-btrfs.sh: mkfs.btrfs; subvols @, @home, @nix, @snapshots; mount compress=zstd,discard=async,noatime; ESP → /boot.
  - install-ext4.sh: mkfs.ext4; noatime; ESP → /boot; services.fstrim.enable.
  - install-xfs.sh: mkfs.xfs; noatime; ESP → /boot; services.fstrim.enable.
  - install-bcachefs.sh (exp): verifica kernel; requiere EXPERIMENT; mkfs --compression=zstd; subvols raíz/home/nix/var*; fstab explícito; nodev/noexec en var/log y var/cache.
  - install-zfs.sh: verifica módulo zfs; advierte sobre ABI kernel/ZFS; zpool con ashift=12, autotrim, zstd, etc.; datasets legacy; networking.hostId; autoScrub; fstrim.
  - install-btrfs-boot-mirror.sh: requiere dos discos; RAID1 (-m/-d raid1); /boot y /boot2; mirroredBoots comentado.
  - install-zfs-boot-mirror.sh: zpool mirror; datasets como single; /boot y /boot2; mirroredBoots comentado; hostId.

Mejoras futuras (ideas)
- Tests automáticos (VMs) para instaladores
- Opción con disko
- Perfiles extra o flag para instalar un DE
- TUI más robusto con validaciones y dry-run

Licencia y contribuciones
- Apache-2.0. Traducción al español no vinculante. PRs y issues son bienvenidos.

