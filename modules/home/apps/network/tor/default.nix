{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "network";
  name = "tor";
}
{
  # For description of packages see: https://wiki.archlinux.org/title/Tor
  home.packages = with pkgs; [
    # For relays.
    tor
    # For regular usage.
    ds-omega.gl-tor-browser
  ];
}
