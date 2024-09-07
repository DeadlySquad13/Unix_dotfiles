{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "architecturing";
  name = "yed";
}
{
  home.packages = with pkgs; [
    yed
  ];
  # imports = [
  #   ../java-fonts-fix/default.nix
  # ];
}
