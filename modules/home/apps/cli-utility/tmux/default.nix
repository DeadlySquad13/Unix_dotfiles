{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  harpoon = pkgs.ds-omega.harpoon;

  # Whether harpoon is part of this home's plugin set. `programs.tmux.plugins`
  # is the merged option, so this stays correct even if another module drops it.
  # Plugins may be given bare or as `{ plugin = …; extraConfig = …; }`.
  harpoonEnabled =
    lib.any (
      p: p == harpoon || (p.plugin or null) == harpoon
    )
    config.programs.tmux.plugins;
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "cli-utility";
    name = "tmux";
  }
  {
    programs.tmux = {
      enable = true;

      plugins = with pkgs; [
        tmuxPlugins.resurrect
        # Custom build: pinned past nixpkgs' v0.4.0 (see the package's comment),
        # wrapped so its `fzf`/coreutils dependencies are on PATH.
        ds-omega.harpoon
      ];

      # * Prefix remapping.
      # (Actually <c-space>)
      shortcut = "Space";

      extraConfig =
        ''
          source ~/.config/tmux/old.conf
          source ${./config.conf}
          source ${./smug.conf}
          source ${./projects.conf}
          source ${./project-configurations.conf}
        ''
        + lib.optionalString harpoonEnabled ''
          # harpoon's manual keybindings live in their own file. This is the
          # tmux-level check: `@harpoon_loaded` is set by the plugin's
          # harpoon.tmux when it runs (run-shell is synchronous), so the file
          # is only sourced in servers that actually loaded harpoon. Note the
          # guard must be `if-shell -F`: `%if` is parse-time and would not see
          # the marker set by the queued `run-shell`.
          if-shell -F '#{==:#{@harpoon_loaded},1}' 'source-file ${./harpoon.conf}'
        '';
    };

    # harpoon.conf's bindings call the `harpoon` CLI, which the package exposes
    # as `$out/bin/harpoon`.
    home.packages = lib.optionals harpoonEnabled [harpoon];

    # TODO: Configure properly via nix: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.tmux.enable
    home.file = {
      # Dev.
      ".config/tmux/old.conf" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/tmux/.tmux.conf";
        out-of-store = true;
      };
      # Prod.
      #   ".config/tmux/old.conf".source =
      #       pkgs.fetchFromGitHub {
      #         owner = "DeadlySquad13";
      #         repo = "Wsl2_dotfiles";
      #         rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
      #         hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
      #       }
      #       + "/stow_home/tmux/.tmux.conf";
    };
  }
