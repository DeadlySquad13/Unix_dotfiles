{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
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
