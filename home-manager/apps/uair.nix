{ pkgs, config, ... }:

{
  home.file = {
    ".config/uair" = {
      source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/home-configs/uair;
      recursive = true;
    };
  };

  home.packages = with pkgs; [
    # Extensible pomodoro timer.
    uair
    # Gui dialog for shell scripts. Used for displaying uair stdout timer.
    yad
  ];

  home.shellAliases = {
    uairWork = "uair --config ~/.bookmarks/home-configs/uair/work.toml | yad --progress --no-buttons --css='* { font-size: 80px;  }'";
  };
}
