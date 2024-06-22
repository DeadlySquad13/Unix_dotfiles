{ pkgs, ... }:

# ?: It is available only for macos. Make platform specific packages?
# TODO: Add skhd as dep.
{
  home.file = {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/YabaiWm_config
    ".config/yabai".source = ~/.bookmarks/home-configs/YabaiWm_config;
  };

  home.packages = with pkgs; [
    yabai
  ];
}
