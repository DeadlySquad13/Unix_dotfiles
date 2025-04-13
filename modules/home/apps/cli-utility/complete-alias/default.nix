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
  name = "complete-alias";
}
{
  home.packages = with pkgs; [
    complete-alias
  ];

  programs.bash = {
    # TODO: Get this path without hardcode.
    # I got it from `which complete_alias`
    profileExtra = ''
      [[ -f $HOME/.nix-profile/bin/complete_alias ]] && . $HOME/.nix-profile/bin/complete_alias
    '';

    bashrcExtra = ''
      complete -F _complete_alias sct
    '';
  };
}
