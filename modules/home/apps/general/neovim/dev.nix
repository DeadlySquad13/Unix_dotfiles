{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfDevEnabled;
  home-scripts = lib.${namespace}.get-path { inherit config; cb = p: p.home-scripts; as-string = true; };
  nvimScript = "${home-scripts}/NeoVim__/nvimDev.sh";
in
  mkIfEnabled {
    inherit config;
    category = "general";
    name = "neovim";
    extraPredicate = mkIfDevEnabled;
  }
  {
    home.file = {
      # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3

      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      # STYLE: on Linux it's just this but on Unix it's
      # ...dotfiles-/shared-/_configs...
      ".local/dotfiles-/_configs/nvim/-dev" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
        out-of-store = true;
      };
      ".config/nvim-dev" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
        out-of-store = true;
      };

      ${nvimScript} = {
        text = ''
          #!/usr/bin/env bash
          NVIM_APPNAME=nvim-dev nvim "$@"
        '';
        executable = true;
      };
    };
    home.shellAliases = {
      nvim-dev = nvimScript;
      vi-dev = nvimScript;
    };
  }
