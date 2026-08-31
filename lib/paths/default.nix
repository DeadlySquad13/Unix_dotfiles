{
  namespace,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.nixpkgs.lib) strings;
  inherit (lib.${namespace}) disabled enabled;
in {
  # TODO: We have a bit strange hard-dependency on
  # `config.lib.${namespace}.paths` in this function. If it's missing, it will
  # be `{}` => path will be `null` => nix will throw error. We should either
  # make it more friendly error "set config...paths" or further abstract this
  # function from our config.
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
  Resolve `~/.bookmarks/<x>` keys to their symlink-free real paths **only when
  they are present in the host's runtime-home-bridge attrset** (`resolutions`).
  Keys the runtime bridge does not manage, and any other value (plain strings or
  Nix path literals with store-copy semantics), pass through unchanged.

  This is narrow on purpose: only links the runtime-home-bridge actually creates
  are necessarily symlinks that a Nix path context cannot traverse. Home Manager
  bookmarks (`mkOutOfStoreSymlink`) and plain build-host paths are fine as-is and
  must not be rewritten. If a host does not enable the bridge, pass `{}` and
  nothing is resolved.
  */
  resolveRuntimePaths = { homeDirectory, resolutions }: paths:
    builtins.mapAttrs (_name: value: let
      s = builtins.toString value;
      key =
        if strings.hasPrefix "~/" s
        then "${homeDirectory}/${strings.removePrefix "~/" s}"
        else s;
    in
      if builtins.hasAttr key resolutions then resolutions.${key} else value) paths;

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
    recursive ? false,
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
      recursive = recursive || out-of-store;
    };
}
