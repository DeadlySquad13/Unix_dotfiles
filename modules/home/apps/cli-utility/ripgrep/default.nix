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
  name = "ripgrep";
}
{
  home.packages = with pkgs; [
    ripgrep
  ];

  # Need at least something in $RIPGREP_CONFIG_PATH to avoid error of ripgrep
  # "No such file or directory".
  home.file = {
    ".ripgreprc".text = ''
        # Add my 'web' type.
        --type-add
        web:*.{html,css,js}*
      '';
  };
}
