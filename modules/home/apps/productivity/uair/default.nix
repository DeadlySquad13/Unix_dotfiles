{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "uair";
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  home = {
    file = {
      ".config/uair" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.home-configs}/uair";
        out-of-store = true;
      };
    };

    packages = with pkgs; [
      # Extensible pomodoro timer.
      uair
      # Gui dialog for shell scripts. Used for displaying uair stdout timer.
      yad
    ];

    shellAliases = {
      uairWork = "uair --config ~/.bookmarks/home-configs/uair/work.toml | yad --progress --no-buttons --css='* { font-size: 80px;  }'";
    };
  };
}
