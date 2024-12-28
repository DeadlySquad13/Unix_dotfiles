{ config, namespace, pkgs, lib, ... }:
let 
  config-source = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.home-configs}/YabaiWm_config";
      out-of-store = false;
    };
in
# ?: It is available only for macos. Make platform specific packages?
# TODO: Add skhd as dep.
{
  home.file = lib.mkIf (config-source != {}) {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/YabaiWm_config
    ".config/yabai" = config-source;
  };

  home.packages = with pkgs; [
    yabai
  ];
}
