[English](./quickstart-bcachefs.md) | Español

# Guía rápida: instalador bcachefs (experimental)

Usa esto cuando experimentes con bcachefs en un solo disco. No recomendado para producción.

Prerrequisitos
- Firmware UEFI (se usa systemd-boot)
- Ejecutar como root (sudo está bien)
- El kernel soporta bcachefs (módulo o integrado)
- Sin sistemas de archivos bcachefs montados

Pasos
1) Ejecutar el instalador
```bash
./scripts/install-bcachefs.sh
```
2) Seguir las indicaciones
- Debes escribir EXPERIMENT para reconocer los riesgos
- Zona horaria, mapa de teclado, nombre de host, nombre de usuario (y contraseña si OpenSSL está disponible)
- Selecciona el disco de destino
- Confirma la acción destructiva escribiendo INSTALL
3) Lo que hace el script
- Particiona el disco: 1 GiB ESP (FAT32), resto bcachefs
- Crea subvolúmenes: @ → /, @home → /home, @nix → /nix, @var* para las divisiones de /var
- Monta con compress=zstd,noatime; ESP en /mnt/boot
- Escribe configuration.nix con boot.supportedFilesystems y soporte en initrd
- Ejecuta nixos-install
4) Reinicia en tu sistema experimental

Barandillas
- Requiere reconocimiento explícito de EXPERIMENT
- Verifica soporte del kernel vía /proc/filesystems y modprobe
- Se niega si hay sistemas de archivos bcachefs montados
- Advierte en entornos contenedorizados y cuando faltan efivars UEFI

