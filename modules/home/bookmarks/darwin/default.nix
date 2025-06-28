{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;

  # In most cases we jump directly into folder. This way common .envrc wouldn't
  # be hooked. This envrc allows us to source it from a central point in each
  # subdirectory.
  envrc =
    /*
    bash
    */
    ''
      source_env_if_exists ../.envrc

      # vi:ft=bash
    '';

  woodpecker-path = "${config.home.homeDirectory}/Projects/--professional/Rutube__/Woodpecker";
  # Project local disable of automatic corepack pinning of package manager version.
  woodpecker-corepack =
    lib.attrsets.concatMapAttrs
    (name: value: {"${woodpecker-path}/${name}" = value;})
    (
      {
        ".envrc".text =
          /*
          bash
          */
          ''
            dotenv ./.env.dev

            # vi:ft=bash
          '';
        ".env.dev".text =
          /*
          bash
          */
          ''
            # Disable auto-setting of `packageManager` when corepack is enabled.
            COREPACK_ENABLE_AUTO_PIN=0

            # vi:ft=bash
          '';
      }
      # Iterating over all worktrees.
      # TODO: Ideally should be based on current worktree structure, not just
      # hardcoded paths.
      // lib.attrsets.concatMapAttrs (projectName: value: {"${projectName}/.envrc".text = envrc;})
      {
        "CurrentTask" = "";
        "CurrentTask1" = "";
        "Epic" = "";
        "Main" = ""; # Actually symlink to Woodpecker.git. Woodpecker.git is also symlinked to Master.
        "Release" = "";
        "Review" = "";
      }
      // {
        # Local for repository, personal to our workflow gitignore file.
        # https://git-scm.com/docs/gitignore,
        # https://stackoverflow.com/questions/1753070/how-do-i-configure-git-to-ignore-some-files-locally
        "Woodpecker.git/.git/info/exclude".text =
          /*
          gitignore
          */
          ''
            # Usually not ignored, but our members don't use it, it's for our personal
            # solution of a corepack issue.
            .envrc
          '';
      }
    );
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "bookmarks";
    name = "darwin";
    extraPredicate = lib.${namespace}.mkIfDarwin;
  }
  {
    # See `darwinConfigurations.creamsoda.config.home-manager.users.apakalo.home.file.`
    # in nix-repl to debug.
    home.file =
      builtins.mapAttrs
      (name: value: source { inherit config; get-path = _p: value; out-of-store = true; })
      (
        lib.attrsets.concatMapAttrs (name: value: {".bookmarks/${name}" = value;})
        {
          "ChronoIndex" = "~/ChronoIndex";
          "KnowledgeBase__Data" = "~/KnowledgeBase__Data";
          "kbd" = "~/KnowledgeBase__Data";
          "kbn" = "~/KnowledgeBase__Data/Notes";
        }
      )
      // woodpecker-corepack;
  }
