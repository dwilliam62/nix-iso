{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.chaotic.nixosModules.default
  ];

  nixpkgs.config.allowUnfree = true;
  # Set environment variable for allowing non-free packages
  environment.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ]; # enable nix command and flakes

  nixpkgs.overlays = [
    (final: prev: {
      bcachefs-tools = inputs.bcachefs-tools.packages.${pkgs.system}.bcachefs-tools;
    })
    # Work around upstream breakage: pygls tests fail with lsprotocol API mismatch on python3.13
    (final: prev: {
      python3Packages = prev.python3Packages.overrideScope (pyFinal: pyPrev: {
        pygls = pyPrev.pygls.overrideAttrs (old: {
          doCheck = false;               # skip pytest phase
          pytestCheckPhase = ''true'';   # no-op safeguard
        });
        i3ipc = pyPrev.i3ipc.overrideAttrs (old: {
          doCheck = false;               # async tests failing under pytest/python 3.13
          pytestCheckPhase = ''true'';   # no-op safeguard
        });
      });
    })
  ];

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  boot.zfs.package = lib.mkOverride 99 pkgs.zfs_cachyos;
  boot.supportedFilesystems = [
    "btrfs"
    "vfat"
    "f2fs"
    "xfs"
    "ntfs"
    "cifs"
    "bcachefs"
    "ext4"
    "zfs"
  ];

  environment.systemPackages = with pkgs; [
    # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    vim
    git
    curl
    parted
    efibootmgr
    tmux
  ];

  # Enable guest services; systemd gates them to VMs only.
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.virtualbox.guest.enable = true;
  services.vmwareGuest.enable = true;

  # Provide a simple, compatible tmux configuration at /etc/tmux.conf
  environment.etc."tmux.conf".text = ''
    # Prefix on Ctrl-a (classic GNU screen feel)
    set -g prefix C-a
    unbind C-b
    bind C-a send-prefix

    # Mouse support
    set -g mouse on

    # Vi-style keys in copy-mode and status line
    set -g mode-keys vi
    set -g status-keys vi

    # Start windows/panes at 1
    set -g base-index 1
    setw -g pane-base-index 1
    set -g renumber-windows on

    # Status bar at top
    set -g status-position top

    # 24-bit color passthrough; compatible default terminal inside tmux
    set -sg terminal-overrides ",*:RGB"
    set -g default-terminal "screen-256color"
    # If you know tmux-256color exists on your systems, you can use:
    # set -g default-terminal "tmux-256color"

    # History
    set -g history-limit 5000

    # Unbind default split keys (we’ll rebind below)
    unbind %
    unbind '"'

    # Directional pane selection (prefix + h/j/k/l)
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # Quick kill pane
    bind x kill-pane

    # Split using current pane path
    bind '|' split-window -h -c "#{pane_current_path}"
    bind "\\" split-window -fh -c "#{pane_current_path}"
    bind '-' split-window -v -c "#{pane_current_path}"
    bind '_' split-window -fv -c "#{pane_current_path}"

    # Basic window controls
    bind c new-window
    bind n next-window
    bind p previous-window

    # Reload config
    unbind r
    bind r source-file /etc/tmux.conf \; display-message "Reloaded /etc/tmux.conf"

    # Toggle zoom
    bind -r m resize-pane -Z

    # Handy utilities
    bind t clock-mode
    bind q display-panes
    bind u refresh-client
    bind o select-pane -t :.+

    # NOTE:
    # - Removed popups/menus and external tool bindings for maximum compatibility.
    # - Avoid terminal-specific or version-specific features.
  '';

  # Wireless network and wired network is enabled by default
}
