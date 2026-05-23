{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "productivity";
    name = "taskjuggler";
  }
  {
    home.packages = with pkgs; [
      taskjuggler
    ];
  }
