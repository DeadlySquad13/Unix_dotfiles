{
  config,
  lib,
  namespace,
  ...
}: let
  envrc = /*bash*/''
    source_env_if_exists ../.envrc

    # vi:ft=bash
  '';
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
      (name: value: {source = config.lib.file.mkOutOfStoreSymlink value;})
      (
        lib.attrsets.concatMapAttrs (name: value: {".bookmarks/${name}" = value;})
        {
          "ChronoIndex" = ~/ChronoIndex;
        }
      )
      // (
        lib.attrsets.concatMapAttrs (name: value: {"${config.home.homeDirectory}/Projects/--professional/Rutube__/Woodpecker/${name}" = value;})
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
          // lib.attrsets.concatMapAttrs (projectName: value: {"${projectName}/.envrc".text = envrc;})
          {
            "CurrentTask" = "";
            "CurrentTask1" = "";
            "Epic" = "";
            "Main" = "";
            "Release" = "";
            "Review" = "";
          }
        )
      );
  }
