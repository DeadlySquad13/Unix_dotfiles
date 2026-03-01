{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "browser-sync";
}
{
  home.packages = with pkgs; [
    # FIX: error: 'browser-sync' has been removed because it was unmaintained in nixpkgs
    # I think we may just change it to something similar.
    # nodePackages_latest.browser-sync
  ];
}
