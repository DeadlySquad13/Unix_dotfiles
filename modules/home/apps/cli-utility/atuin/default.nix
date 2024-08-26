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
  name = "atuin";
}
{
  home.packages = with pkgs; [
    atuin
  ];
}
