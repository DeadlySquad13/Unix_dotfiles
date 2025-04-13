{
  lib,
  namespace,
  config,
  # pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "karabiner-elements";
  extraPredicate = lib.${namespace}.mkIfDarwin;
}
# TODO:Enable Fn keys.
{
  # Prod.
  home.file = {
    # Dev.
    ".config/karabiner" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.home-configs}/Keymappings__Karabiner_config";
      out-of-store = true;
    };
    # Prod.
    /*
    pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "Keymappings__Karabiner_config";
      rev = "103baafc016bfab2bd57bf7027bf21f18ff463c1";
      hash = "sha256-gYLMzR5MF9s4Lp70n39jA9OS8miEOi1FaK+0xg/5he4=";
    };
    */
  };

  # FIX: Doesn't work for some reason, installed just from brew.
  # It needs to fiddle quite a lot with system settings to enable daemons and
  # keyboard grabber so it may be better to install via nix-darwin.
  # home.packages = with pkgs; [
  #   karabiner-elements
  # ];
}
