{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  # NOTE: Snowfall passes its own merged `lib`, which does not carry Home
  # Manager's `hm` fixpoint. `config.lib` is Home Manager's extended lib
  # (`lib.hm`), so the DAG helper is reached through it.
  inherit (config.lib) dag;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "system-services";
    name = "termfilechooser";
  }
  {
    xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=gtk
      org.freedesktop.impl.portal.FileChooser=termfilechooser
    '';

    xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=/usr/share/xdg-desktop-portal-termfilechooser/ranger-wrapper.sh
      default_dir=$HOME
      env=TERMCMD=wezterm start --always-new-process --
      env=PATH=/usr/local/bin:/usr/bin:/home/ds13/.nix-profile/bin
      open_mode=suggested
      save_mode=suggested
    '';

    # Kept as a fallback only: awesome is started via exec from xinitrc and
    # does not source environment.d; the authoritative X delivery is the
    # Ansible-managed /usr/local/etc/X11/xinit/xinitrc.d drop-in.
    xdg.configFile."environment.d/90-portal.conf".text = ''
      GTK_USE_PORTAL=1
      QT_QPA_PLATFORMTHEME=xdgdesktopportal
    '';

    home.sessionVariables = {
      GTK_USE_PORTAL = "1";
      QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
    };

    home.activation.termfilechooserReloadNotice = dag.entryAfter ["writeBoundary"] ''
      echo "xdg-desktop-portal termfilechooser config updated. Re-login X and run: systemctl --user restart xdg-desktop-portal.service" >&2
    '';
  }
