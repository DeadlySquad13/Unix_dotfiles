{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfStageEnabled;
  home-scripts = lib.${namespace}.get-path { inherit config; cb = p: p.home-scripts; as-string = true; };
  nvimScript = "${home-scripts}/NeoVim__/nvimStage.sh";
in
  mkIfEnabled {
    inherit config;
    category = "general";
    name = "neovim";
    extraPredicate = mkIfStageEnabled;
  }
  {
    home.file = {
      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      ".local/dotfiles-/_configs/nvim/-stage" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
      };
      ".config/nvim-stage" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
      };

      ${nvimScript} = {
        text = ''
          #!/usr/bin/env bash
          NVIM_APPNAME=nvim-stage nvim "$@"
        '';
        executable = true;
      };
    };
    home.shellAliases = {
      nvim-stage = nvimScript;
      vi-stage = nvimScript;
    };
  }
