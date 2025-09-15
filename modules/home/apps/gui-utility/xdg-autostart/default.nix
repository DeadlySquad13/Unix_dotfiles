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
    # ".config/autostart/v2rayN.desktop".source = /usr/share/applications/v2rayN.desktop;
    # Autostart (and stay minimized but I guess it's not reflected here).
    ".config/autostart/v2rayN.desktop".text = /*desktop*/ ''
      [Desktop Entry]
      Type=Application
      Exec=/usr/lib/v2rayN/v2rayN
      Hidden=false
      NoDisplay=false
      X-GNOME-Autostart-enabled=true
      Name[en_US]=v2rayN
      Name=v2rayN
      Comment[en_US]=v2rayN
      Comment=v2rayN
    '';

    # QUESTION: Better to be moved to ferdium directly but it requires that
    # this module is loaded. How to organize such cases better?
    # REFACTOR: Can be made via xdg.desktopEntries? Or if it has hardcoded
    # location, then generation desktopEntry in autostart folder via
    # makeDesktopItem ([Source](https://github.com/NixOS/nixpkgs/blob/07dec8191796fa9cd8806b1bac24a49ec05e5d2d/pkgs/build-support/make-desktopitem/default.nix),
    # [Example](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ob/obsidian/package.nix#L7))
    ".config/autostart/ferdium.desktop".text = /*desktop*/ ''
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
