{
  namespace,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.nixpkgs.lib) strings;
in {
  get-path = {
    config,
    cb,
  }: let
    path = cb config.lib.${namespace}.paths;
  in
    if strings.hasPrefix "~/" path
    then /${config.home.homeDirectory}/${strings.removePrefix "~/" path}
    else /${strings.removePrefix "/" path};

  /*
  @usage
    Assign result of this function to a `home.file."somepath"`.
  @example
    home.file.".config/karabiner" = lib.${namespace}.source {
      inherit config;
      get-path = p: "~/.local/dotfiles-/home-/_scripts/Keymappings__Karabiner_scripts";
      out-of-store = true;
    };

  */
  source = {
    config,
    get-path,
    out-of-store ? false,
  }: let
    path = lib.${namespace}.get-path {
      inherit config;
      cb = get-path;
    };
  in {
    # Reference for mkOutOfStoreSymlink: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    source =
      if !out-of-store
      then path
      else config.lib.file.mkOutOfStoreSymlink path;
    recursive = out-of-store;
  };
}
