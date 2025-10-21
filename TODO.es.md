<!--
Author: Don Williams (aka ddubs)
Created: 2025-10-21
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./TODO.md) | Español

# TODO (Mejoras del ISO de Instalación/Rescate)

Experiencia de rescate

- [ ] Añadir un rescue-menu.sh guiado para tareas comunes:
  - [ ] Montar y hacer chroot en un NixOS instalado (bind mounts + nixos-enter)
  - [ ] Reinstalar systemd-boot y regenerar entradas EFI
  - [ ] Btrfs: listar/crear/revertir snapshots (@ y @home)
  - [ ] Salud del disco: SMART/salud NVMe, pruebas rápidas con badblocks
  - [ ] Imagen: asistente de ddrescue (origen, destino, mapfile)
- [ ] Proporcionar configuraciones predeterminadas de snapper para root y home (script opcional de activación)
- [ ] Wrapper de ayuda para activar los timers de btrfsmaintenance (si se desea)

Mejoras del instalador

- [x] Añadir scripts opcionales para crear espejado en la unidad de arranque donde sea compatible
- [ ] Añadir creación de archivo de swap opcional en Btrfs (con ajustes correctos de NOCOW/compresión)
- [ ] Permitir elegir flujo de cifrado de disco (LUKS en Btrfs)
- [ ] Opcional separar /var o presets de subvolúmenes adicionales
- [x] Opción para establecer contraseñas con hash de forma no interactiva (prompt -> openssl -6) — Implementado en todos los scripts del instalador cuando openssl está disponible

Seguridad y acceso

- [ ] ISO en vivo: alternar SSH a modo solo claves (variable de entorno o flag)
- [ ] Añadir presets de firewall simples para contextos de rescate vs. instalación

Documentación y UX

- [ ] scripts/README: añadir ejemplos para tareas de rescate (chroot, reparación de arranque, ddrescue)
- [ ] README.md: documentar el uso de scripts/build-iso.sh y los perfiles
- [ ] Tools-Included.md: mantener sincronizado cuando cambie el conjunto de herramientas (en curso)

CI/CD

- [ ] Añadir job de CI para construir el artefacto de la ISO nixos-recovery en pushes a la rama
- [x] Añadir flake checks en CI (nix flake check) — Implementado vía .github/workflows/check-flake.yml

Cobertura de sistemas de archivos

- [ ] Asegurar herramientas completas y soporte en vivo para sistemas de archivos principales:
  - [x] EXT4: e2fsprogs (fsck.ext4, resize2fs, tune2fs, etc.) — incluido en el ISO en vivo y el instalador
  - [x] XFS: xfsprogs (xfs_repair, xfs_growfs, etc.) — incluido en el ISO en vivo y el instalador
  - [x] Bcachefs: bcachefs-tools — incluido en el ISO en vivo y el instalador
  - [x] ZFS: herramientas userland (zfs, zpool) y disponibilidad del módulo del kernel en el ISO en vivo (alineado con boot.zfs.package) — userland provisto desde config.boot.zfs.package; kernel/paquete alineado en common.nix; instalador existente
- [ ] Verificar flujos de montaje/reparación desde el ISO en vivo y documentar en HOWTO/Tools-Included
- [x] Considerar añadir cifs-utils para montajes SMB/CIFS (además de nfs-utils) — incluido (también se añadió nfs-utils)

