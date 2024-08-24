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
  name = "gtrash";
}
{
  home = {
    packages = with pkgs; [
      gtrash
    ];

    shellAliases = {
      # Trash move (easy to change to rm).
      tm = "gtrash put";
      rm = "echo -e 'If you want to use rm really, then use \"\\\\rm\" instead.'; false";
    };
  };

  # TODO: Move to layer.
  programs.ranger = {
    mappings = {
      # "ll" = "console gtrash";
      "ll" = lib.mkForce "shell -p gtrash put %s 2>&1";
    };
  };
}
