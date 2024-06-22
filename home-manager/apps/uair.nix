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
}
