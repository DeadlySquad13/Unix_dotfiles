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
    # By default get-path returns path stored in nix store. If you need a plain
    # string, set to true. Useful, for example, in `home.file`:
    # home.file."${lib.${namespace}.get-path { inherit config; cb = p: p.home-scripts; as-string = true; }}" = ''some script'';
    # Without this setting it would store it will try to first store it into
    # path. Because we're trying to create it to begin with, it will of course
    # fail. In the end we're just trimming "~/..." from our strings in `paths` to get them in
    # a form of "/home/user/..." that is compatible (along with "./...") in this context.
    as-string ? false,
  }: let
    config-paths = config.lib.${namespace}.paths or {};
    path = if config-paths != {} then cb config-paths else builtins.null;
  in
  rec {
    store-path = if strings.hasPrefix "~/" path
      then /${config.home.homeDirectory}/${strings.removePrefix "~/" path}
      else /${strings.removePrefix "/" path};
    result = if !as-string then store-path else builtins.toString store-path;
  }.result;

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
