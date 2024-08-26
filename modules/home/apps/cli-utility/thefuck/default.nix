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
  name = "thefuck";
}
{
  home.packages = with pkgs; [
    thefuck
  ];

  programs.bash = {
    bashrcExtra = 
      ''
        eval $(thefuck --alias pls)
      '';
  };
}
