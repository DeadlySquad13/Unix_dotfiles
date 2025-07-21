{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  # Layers: math, data-science.
  category = "cli-utility";
  name = "visidata";
}
{
  home.packages = with pkgs; [
    visidata
  ];
  home.file = {
    ".visidatarc".source = ./.visidatarc;
  };
}
