<!--
Author: Don Williams (aka ddubs)
Created: 2025-08-27
Project: https://github.com/dwilliam62/nix-iso
-->

[English](./ddubsos-zaneyos-install-iso-plan.md) | Español

# Plan: ISOs de instalación de un paso para zaneyos (25.05) y ddubsos (25.11)

Objetivo
- Producir dos ISOs en vivo separadas usando el marco existente de nix-iso que realicen una instalación de un solo paso de sistemas completamente configurados:
  - zaneyos: NixOS 25.05 estable, enfocado en Hyprland
  - ddubsos: NixOS 25.11 inestable, con apps y escritorios ampliados
- Mantener la ISO en vivo mínima; los scripts del instalador obtendrán o copiarán la flake del proyecto y ejecutarán nixos-install --flake para una instalación de un solo paso.

Repositorios / entradas
- nix-iso (este repo): base del ISO, herramientas de recuperación, TUI, documentación
- zaneyos: ~/zaneyos (flake que expone nixosConfigurations para sistemas de destino)
- ddubsos: ~/ddubsos (flake que expone nixosConfigurations para sistemas de destino)

Enfoques
1) Instaladores conscientes del proyecto (recomendado)
   - Añadir scripts/install-zaneyos.sh y scripts/install-ddubsos.sh basados en los existentes install-*.sh.
   - Flujo:
     1. Particionar y montar el destino (GPT: ESP de 1GiB + resto FS; reutilizar barandillas y flujo actuales).
     2. Generar hardware-configuration.nix vía nixos-generate-config --root /mnt.
     3. Proveer la flake del proyecto bajo /mnt/etc/nixos (clonar por red O copiar desde el repo embebido).
     4. Colocar hardware-configuration.nix donde el proyecto lo espere O inyectarlo vía un módulo overlay.
     5. Ejecutar nixos-install --root /mnt --flake /mnt/etc/nixos#<target>.
   - Pros: Compatible con distintos canales; el sistema instalado fija su propia flake. Cambios mínimos en nix-iso.
   - Contras: Requiere que los proyectos expongan nixosConfigurations adecuados y acepten el hardware config generado.

2) Embebido de proyectos en la ISO (capaz offline)
   - Empaquetar ~/zaneyos y ~/ddubsos en la ISO (derivaciones en recovery/recovery-tools.nix) bajo p. ej. /share/nix-iso-projects/{zaneyos,ddubsos}.
   - El instalador copia desde la ruta del store a /mnt/etc/nixos.
   - Pros: Funciona sin red; verdaderamente de un solo paso.
   - Contras: Recompilar la ISO cada vez que cambie el proyecto (o permitir git pull opcional si hay red).

3) Perfiles ISO por proyecto
   - Crear perfiles nixos-zaneyos y nixos-ddubsos que incluyan proyectos embebidos e instaladores y docs específicos del proyecto.
   - Pros: UX muy clara: cada ISO está dedicada a un proyecto.
   - Contras: Más perfiles a mantener (aceptable dado la estructura actual).

Camino recomendado
- Implementar primero el Enfoque 1, con embebido opcional del Enfoque 2 para instalaciones offline.
- Mantener una familia de ISO por proyecto si se desea más adelante (Enfoque 3) añadiendo perfiles.

Diseño de scripts de instalación (zaneyos y ddubsos)
- Base: copiar set -euo pipefail, root/sudo, higiene de PATH, checks de dependencias, confirmación destructiva, selección de disco, esquema GPT, y montaje de tus instaladores existentes.
- Pasos:
  1. Selección de disco, borrado, particionado (ESP + datos), mkfs, montaje (FS puede ser ext4/XFS/Btrfs/ZFS según preferencia; lo más simple es ext4 o Btrfs para estos instaladores).
  2. nixos-generate-config --root /mnt (usa --no-filesystems si prefieres declarar montajes explícitos luego).
  3. Obtener la flake del proyecto:
     - Online: git clone https://<repo> /mnt/etc/nixos (o ssh/https según entorno).
     - Offline: cp -a /nix/store/<symlink-del-proyecto>/ /mnt/etc/nixos (si está embebido).
  4. Manejo de hardware config:
     - Drop-in: conservar /mnt/etc/nixos/hardware-configuration.nix e importarlo en el proyecto (simple recomendado).
     - Inyección vía overlay: escribir un módulo junto a la flake que importe el hardware-configuration.nix generado y opciones del usuario (zona horaria, keymap, usuario) para no tocar el proyecto.
  5. nixos-install --root /mnt --flake /mnt/etc/nixos#<target> (atributo expuesto por la flake del proyecto).
  6. Mensaje post-instalación; prompt de reinicio opcional.

Hardware-configuration.nix: dos patrones
- Importación directa (preferido): la flake del proyecto importa ./hardware-configuration.nix como parte de sus módulos.
- Módulo overlay: el instalador escribe un módulo local (p. ej., overlay.nix) que importa el módulo del proyecto y /mnt/etc/nixos/hardware-configuration.nix, y pasa elecciones del instalador (usuario/zona horaria/keymap). Luego instalar con --flake "/mnt/etc/nixos?dir=./#<target>" más -I o desde una flake compuesta temporal.

Canales y compatibilidad
- El canal de la ISO en vivo puede diferir del canal del sistema instalado. nixos-install --flake usa el nixpkgs fijado por el proyecto.
- Para mayor fidelidad, opcionalmente podemos construir una ISO de zaneyos contra 25.05 y una de ddubsos contra 25.11, pero no es obligatorio.

Integración con TUI
- Añadir entradas de menú:
  - Instalar zaneyos (un paso)
  - Instalar ddubsos (un paso)
- Flags:
  - --source=embedded|git (elegir entre copia embebida en la ISO o clon online)
  - --target=<flakeAttr> (seleccionar atributo host/sistema a instalar)

Docs y UX
- Incluir fragmentos del README de cada proyecto en /etc/nix-iso-docs (HTML vía pandoc + Markdown) para ambas ISOs.
- Mantener el hint minimal en consola y lanzadores gráficos; añadir páginas quickstart específicas si ayuda.

Seguridad y barandillas
- Reutilizar todas las salvaguardas actuales: aviso de contenedor, nota sobre efivars UEFI, comprobaciones de montajes en conflicto, checks de módulo ZFS (si aplica), confirmación explícita INSTALL.
- No mostrar secretos; hashear contraseñas con openssl -6 si se solicitan.

Riesgos / consideraciones
- Si la estructura del proyecto espera una ruta específica para hardware-configuration.nix, asegurar que el instalador lo mueva o referencie correctamente.
- MirroredBoots: habilitar solo cuando esté disponible en nixpkgs para evitar problemas de evaluación.
- Necesidad de reconstruir la ISO cuando se embeben fuentes del proyecto.
- Variabilidad de acceso a red: ofrecer modos offline y online.

Checklist de próximos pasos
- Confirmar las salidas de flake de cada proyecto (qué nixosConfigurations instalar por defecto) y si importarán un ./hardware-configuration.nix local.
- Decidir el FS para estos instaladores (ext4/XFS por simplicidad o Btrfs con subvolúmenes).
- Implementar dos instaladores: scripts/install-zaneyos.sh y scripts/install-ddubsos.sh (clonar/copiar + nixos-install --flake).
- Opcionalmente embeber ~/zaneyos y ~/ddubsos en la ISO y añadir un flag --source en los instaladores.
- Actualizar el TUI para añadir las nuevas entradas y docs que referencien el flujo de un solo paso.
- Considerar perfiles ISO separados por proyecto tras validar los scripts.
