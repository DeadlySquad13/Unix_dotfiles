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
  name = "vue";
}
{
  home.packages = with pkgs; [
    vue
  ];
  # imports = [
  #   ../java-fonts-fix/default.nix
  # ];
}
