{
  namespace,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.nixpkgs.lib) strings;
  inherit (lib.${namespace}) disabled enabled;
in {
  get-path = {
    config,
    cb,
  }: let
    config-paths = config.lib.${namespace}.paths or {};
    path = if config-paths != {} then cb config-paths else builtins.null;
  in
    if path == builtins.null then path
    else
      if strings.hasPrefix "~/" path
      then /${config.home.homeDirectory}/${strings.removePrefix "~/" path}
      else /${strings.removePrefix "/" path};

  /*
  @usage
    Assign result of this function to a `home.file."somepath"`.
  @example
    home.file.".config/karabiner" = lib.${namespace}.source {
      inherit config;
      get-path = p: p.home-configs and "${p.home-configs}/YabaiWm_config" or "~/.config/.yabai";
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
  in
    if path == builtins.null then {} else
    {
      # Reference for mkOutOfStoreSymlink: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
      source =
        if !out-of-store
        then path
        else config.lib.file.mkOutOfStoreSymlink path;
      recursive = out-of-store;
    };
}
