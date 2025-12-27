# hyprland-btw Integration into nix-iso

## Overview

hyprland-btw has been integrated into the nix-iso recovery environment as a standard installer option, alongside ddubsOS and ZaneyOS. This document describes the changes, design decisions, and usage.

## What Changed

### 1. New Install Script: `scripts/install-hyprland-btw.sh`

A new 604-line bash installer script was created, adapted from the hyprland-btw project for compatibility with nix-iso's recovery environment.

**Key features:**
- **GPU Profile Detection**: Automatic detection of NVIDIA, AMD, Intel, or VM graphics (with manual fallback)
- **Configuration Customization**: Interactive prompts for:
  - Timezone (default: America/New_York)
  - Hostname (default: hyprland-btw)
  - Username (default: nixos or current user)
  - Keyboard layout and console keymap
- **Repository Cloning**: Clones hyprland-btw from GitHub if not already present
- **Dynamic User Management**: Supports username changes; adds new user entries and enables `users.mutableUsers` when needed
- **Hardware Configuration**: Multiple fallback strategies to obtain hardware-configuration.nix
- **Non-interactive Mode**: `--non-interactive` flag for automated deployments
- **Logging**: All output logged to timestamped file

### 2. TUI Menu Integration: `scripts/tui/modules/installers.sh`

Added hyprland-btw as a standard installer option in the TUI menu:

```bash
_add_installer_item \
  hyprland_btw \
  "Install hyprland-btw (GPU/user/keyboard config; flake-based)" \
  "if [ -x ./scripts/install-hyprland-btw.sh ]; then ./scripts/install-hyprland-btw.sh; elif [ -x \"$SCRIPT_DIR/install-hyprland-btw.sh\" ]; then \"$SCRIPT_DIR/install-hyprland-btw.sh\"; else install-hyprland-btw.sh; fi"
```

The option appears in the "Standard installers" group alongside ddubsOS and ZaneyOS options.

## Design Decisions

### Pattern Synthesis

The script combines elements from both hyprland-btw and ZaneyOS approaches:

| Aspect | hyprland-btw | ZaneyOS | Implementation |
|--------|--------------|---------|-----------------|
| **User Creation** | Declarative in config.nix | Declarative + variables.nix | Declarative + dynamic patching |
| **Password Setup** | Not in installer; post-boot | Not in installer | Post-boot via `passwd` |
| **Repository** | Uses existing local repo | Clones from remote | Clones; supports existing |
| **GPU Profile** | Manual or from list | Auto-detect + confirm | Auto-detect with fallback |
| **Keyboard** | Simple console.keyMap | Full layout/variant/console | All three configurable |

### Key Differences from Original hyprland-btw Script

1. **Repository Cloning**: Original assumed local clone; new version clones from GitHub if needed
2. **Non-interactive Mode**: Added `--non-interactive` flag for CI/automation
3. **Flexible Username**: Original used hardcoded "dwilliams"; new version supports any username
4. **User Preservation**: Detects existing users and enables `users.mutableUsers` to preserve them
5. **Recovery Environment**: Handles hardware config discovery in ISO/installer contexts (multiple fallback paths)

### User Management Strategy

When the chosen username differs from the hardcoded default (`dwilliams`):

1. Enable `users.mutableUsers = true` to prevent system from removing undeclared users
2. Add a new `users.users."<newname>"` block with:
   - `isNormalUser = true`
   - `extraGroups = ["wheel" "input"]`
   - `shell = pkgs.zsh`
3. Keep the original user entry; both can coexist

This preserves backward compatibility while supporting custom usernames.

## Usage

### Interactive Mode (Default)

```bash
./scripts/install-hyprland-btw.sh
```

The script prompts for:
1. GPU profile (auto-detected or manual)
2. Timezone
3. Hostname
4. Username
5. Keyboard layout
6. Console keymap
7. Repository cloning (if needed)
8. Hardware configuration strategy
9. Build confirmation
10. Reboot confirmation

### Non-interactive Mode (Scripted/Automated)

```bash
./scripts/install-hyprland-btw.sh --non-interactive
```

Uses defaults and skips all prompts. Useful for:
- CI/CD pipelines
- Network-based deployments
- Automated testing

### From nix-iso TUI Menu

1. Boot nix-iso recovery ISO
2. Run `nix-iso` (or select from boot menu)
3. Navigate to "Install scripts" → "Standard installers"
4. Select "Install hyprland-btw (GPU/user/keyboard config; flake-based)"
5. Answer configuration prompts
6. System rebuilds and reboots

## Post-Installation

### Password Setup

After first boot, set passwords using:

```bash
# Set your user password
passwd

# Set root password (if needed)
sudo passwd root
```

The installer provides these instructions after successful rebuild.

### System Updates

hyprland-btw updates via:

```bash
# Rebuild system with updated flake inputs
sudo nixos-rebuild switch --flake ~/hyprland-btw/

# Update all inputs and rebuild
nix flake update --flake ~/hyprland-btw && sudo nixos-rebuild switch --flake ~/hyprland-btw/
```

These aliases are configured in `home.nix`:
- `rebuild` → `sudo nixos-rebuild switch --flake ~/hyprland-btw/`
- `update` → Updates flake + rebuilds

## Files Modified/Created

### Created
- `/home/dwilliams/Projects/ddubs/nix-iso/scripts/install-hyprland-btw.sh` (604 lines)
- `/home/dwilliams/Projects/ddubs/nix-iso/docs/HYPRLAND_BTW_INTEGRATION.md` (this file)

### Modified
- `/home/dwilliams/Projects/ddubs/nix-iso/scripts/tui/modules/installers.sh` (lines 28-31)

## Configuration Patching

The script patches hyprland-btw's configuration files using `sed`:

### `configuration.nix`
- `time.timeZone` → User-selected timezone
- `hostName` (in `networking` block) → User hostname
- `console.keyMap` → User console keymap
- `xserver.xkb.layout` → User keyboard layout
- GPU driver enables (amdgpu, intel, nvidia) based on profile
- `vm.guest-services.enable` → Based on GPU profile
- User entries added/modified as needed

### `flake.nix`
- `nixosConfigurations.<name>` → Hostname
- `users."<name>"` → Username reference

### `home.nix`
- `home.username` → User-selected username
- `home.homeDirectory` → `/home/<username>`

## Validation

Both scripts pass bash syntax validation:

```bash
✓ /scripts/install-hyprland-btw.sh syntax is valid
✓ /scripts/tui/modules/installers.sh syntax is valid
```

## Future Improvements

Potential enhancements:

1. **Password Hashing in Config**: Use NixOS password hash support to set initial passwords during build
2. **Git Configuration**: Prompt for git name/email (like ZaneyOS does) for initial commit
3. **SSH Keys**: Support copying SSH keys during installation
4. **Backup Strategy**: Option to keep/integrate existing custom configs
5. **Variant Support**: Handle keyboard variants (intl, dvorak, etc.) like ZaneyOS

## Troubleshooting

### Script Not Found

If `install-hyprland-btw.sh` is not found when selected from TUI:

1. Ensure script is executable: `chmod +x scripts/install-hyprland-btw.sh`
2. Verify from ISO working directory: `ls -la ./scripts/install-hyprland-btw.sh`
3. Check logs: `cat /tmp/nix-iso.log` (or similar ISO log location)

### Network Clone Failure

If cloning fails (no internet or GitHub unavailable):

1. Provide existing local hyprland-btw directory at `$HOME/hyprland-btw`
2. Script will detect and use it
3. Or run in installer context where repo can be mounted

### Hardware Config Generation

If hardware config generation fails, ensure:

1. You have sufficient permissions (`sudo` available)
2. If installing to `/mnt` target, filesystem is mounted
3. pciutils and other tools are present in ISO

## Related Documentation

- **hyprland-btw**: https://github.com/dwilliam62/hyprland-btw
- **ZaneyOS**: https://gitlab.com/zaney/zaneyos
- **nix-iso WARP.md**: `/path/to/WARP.md` (project rules and architecture)
