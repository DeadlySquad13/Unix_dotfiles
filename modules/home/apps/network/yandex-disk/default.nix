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
  name = "yandex-disk";
  extraPredicate = lib.ds-omega.isLinux;
}
{
  home.packages = with pkgs; [
    yandex-disk
  ];
}
