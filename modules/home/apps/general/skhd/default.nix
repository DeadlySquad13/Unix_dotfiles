{
  config,
  namespace,
  pkgs,
  lib,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "skhd";
  extraPredicate = lib.${namespace}.mkIfDarwin;
}
(
  let
    config-source = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Skhd_config";
      out-of-store = true;
    };
  in {
    home.file = lib.mkIf (config-source != {}) {
      # TODO: fetch from repo: https://github.com/DeadlySquad13/Skhd_config
      ".config/skhd" = builtins.trace config-source config-source;
    };

    # Managed by service too. I think these configurations are merged if the
    # inputs are the same (they are) so left it as it for modularity.
    home.packages = with pkgs; [
      skhd
    ];
  }
)
