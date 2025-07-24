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
  name = "fdupes";
}
{
  home.packages = with pkgs; [
    fdupes
  ];
}
