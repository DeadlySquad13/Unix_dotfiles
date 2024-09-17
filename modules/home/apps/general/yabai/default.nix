{ config, namespace, pkgs, lib, ... }:

# ?: It is available only for macos. Make platform specific packages?
# TODO: Add skhd as dep.
{
  home.file = {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/YabaiWm_config
    ".config/yabai" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.home-configs}/YabaiWm_config";
      out-of-store = false;
    };
  };

  home.packages = with pkgs; [
    yabai
  ];
}
