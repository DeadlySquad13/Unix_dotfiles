{ config, namespace, pkgs, lib, ... }:

# ?: It is available only for macos. Make platform specific packages?
{
  home.file = {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/Skhd_config
    ".config/skhd" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Skhd_config";
      out-of-store = false;
    };
  };

  home.packages = with pkgs; [
    skhd
  ];
}
