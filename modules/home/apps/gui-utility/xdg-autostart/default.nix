{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "gui-utility";
  name = "xdg-autostart";
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  home.packages = with pkgs; [
    xorg.xrdb
    dex
  ];

  # TODO: Make paths respect $XDG_CONFIG_HOME.
  home.file = {
    # Applications that are made available through our system-package manager
    # means or from application itself when not packaged via Nix.
    ".config/autostart/v2rayN.desktop".source = /usr/share/applications/v2rayN.desktop;

    # QUESTION: Better to be moved to ferdium directly but it requires that
    # this module is loaded. How to organize such cases better?
    ".config/autostart/ferdium.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Ferdium
      Comment=All your services in one place built by the community
      Exec=ferdium
      StartupNotify=false
      Terminal=false
    '';
  };
}
