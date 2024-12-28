{ config, namespace, pkgs, lib, ... }:

# ?: It is available only for macos. Make platform specific packages?
let config-source = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Skhd_config";
        out-of-store = true;
      };
in
{
  home.file = lib.mkIf (config-source != {}) {
    # TODO: fetch from repo: https://github.com/DeadlySquad13/Skhd_config
    ".config/skhd" = builtins.trace config-source config-source;
  };

  home.packages = with pkgs; [
    skhd
  ];
}
