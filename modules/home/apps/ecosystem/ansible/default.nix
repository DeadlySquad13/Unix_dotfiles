{
  pkgs,
  lib,
  namespace,
  config,
  inputs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ecosystem";
  name = "ansible";
}
{
  home.packages = with pkgs; [
    ansible
  ];
}
