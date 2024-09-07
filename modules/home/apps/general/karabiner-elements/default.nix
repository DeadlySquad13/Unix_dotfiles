{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "karabiner-elements";
}
{
  # Prod.
  home.file = {
    # Dev.
    ".config/karabiner/assets/complex_modifications" = lib.${namespace}.source {
      inherit config;
      get-path = p: "~/.local/dotfiles-/home-/_scripts/Keymappings__Karabiner_scripts";
      out-of-store = true;
    };
    # Prod.
    /*
       pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "Keymappings__Karabiner_scripts";
      rev = "81e44d824c41a63a7a798b6763455fe07647f807";
      hash = "sha256-5bi8uXJYdK+l9SR6Rnr0kXMKsE9YnOop7dihJzgMjqY=";
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
