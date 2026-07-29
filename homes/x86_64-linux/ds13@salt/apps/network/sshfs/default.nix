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
  name = "sshfs";
}
{
  home.packages = with pkgs; [
    sshfs
  ];
}
