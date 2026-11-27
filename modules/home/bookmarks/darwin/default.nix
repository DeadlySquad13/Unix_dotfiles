{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;
  inherit (config.lib.${namespace}) paths;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "bookmarks";
    name = "darwin";
    extraPredicate = lib.${namespace}.isDarwin;
  }
  {
    # See `darwinConfigurations.creamsoda.config.home-manager.users.apakalo.home.file.`
    # in nix repl to debug.
    #
    # Project configs (`.envrc`, `_configs/*.yml`, `_configs/Nix`, `_scripts`,
    # `AutoHub.git/.git/info/exclude`) live in the shared `bookmarks.projects`
    # module (`writeMode = "home.file"` on Darwin). Do not duplicate the model
    # here: `lib/project-configs` is the single source of truth.
    home.file =
      builtins.mapAttrs
      (
        name: value:
          source {
            inherit config;
            get-path = _p: value;
            out-of-store = true;
          }
      )
      (
        lib.attrsets.concatMapAttrs (name: value: {".bookmarks/${name}" = value;}) {
          "ChronoIndex" = "~/ChronoIndex";
          "KnowledgeBase__Data" = "~/KnowledgeBase__Data";
          "kbd" = "~/KnowledgeBase__Data";
          "kbn" = "~/KnowledgeBase__Data/Notes";
          "shared-configs" = paths.shared-configs;
          "shared-projects" = paths.shared-projects;
        }
      );
  }
