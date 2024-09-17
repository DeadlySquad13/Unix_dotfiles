{
  config,
  lib,
  ...
}: {
  # TODO: Plus enable shared bookmarks.
  home.file =
    builtins.mapAttrs
    (name: value: {source = config.lib.file.mkOutOfStoreSymlink value;})
    (
      lib.attrsets.concatMapAttrs (name: value: {".bookmarks/${name}" = value;})
      ({
          "config" = ~/.config;
          "kbd" = ~/KnowledgeBase__Data;
          "projects" = "/Users/aspakalo/Projects";
          "shared-scripts" = ~/shared-scripts;
          # "shared-configs" = ~/shared-configs;
        }
        //
        # More specific.
        # # Projects
        builtins.mapAttrs (name: value: "/Users/aspakalo/Projects/${value}") {
          # Namespaces.
          "ephemeral-projects" = "ephemeral-";
          "interim-projects" = "interim-";

          # Specific projects.
          "lp" = "logistic-platform";
          "shepherd" = "shepherd";
          "kit" = "main-ui-kit";
          "@kit" = "main-ui-kit/packages";
          "@components" = "main-ui-kit/packages/components";
          "kit2" = "main-ui-kit2";
          "@kit2" = "main-ui-kit2/packages";
          "@components2" = "main-ui-kit2/packages/components";
        })
    );
}
