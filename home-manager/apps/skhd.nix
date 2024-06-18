{ pkgs, ... }:

# ?: It is available only for macos. Make platform specific packages?
{
  home.file = {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/Skhd_config
    ".config/skhd".source = ~/.bookmarks/home-configs/Skhd_config;
  };

  home.packages = with pkgs; [
    skhd
  ];
}
