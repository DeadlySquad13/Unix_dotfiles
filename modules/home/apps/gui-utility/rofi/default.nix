# FIX: For some reason wasn't working only here...
{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "gui-utility";
  name = "rofi";
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  programs.rofi = {
    enable = true;

    extraConfig = {
      modes = [
        "window"
        "drun"
        "run"
        "ssh"
        "combi"
      ];
    };
  };
}
