{ config, lib, namespace, ... }:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "bookmarks";
  name = "linux";
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  # TODO: Fix links with "shared-configs/..." on empty system without existing shared-configs
  # link.
  home.file = builtins.mapAttrs
    (name: value: { source = config.lib.file.mkOutOfStoreSymlink value; })
    (
      lib.attrsets.concatMapAttrs (name: value: { ".bookmarks/${name}" = value; } )
      (
        {
          "config" = ~/.config;
          "projects" = ~/Projects;
        } //
        # Linking to shared `archive-resources-`.
        builtins.mapAttrs (name: value: "/shared/archive-resources-/${value}") {
          # TODO: Add subdivision to windows and unix shared configs.
          "shared-configs" = "Shared/_configs";
          "shared-scripts" = "Shared/_scripts";

          # QUESTION: Should be in Shared too?
          "kbd" = "Resources/KnowledgeBase__Data";
          "kbn" = "Resources/KnowledgeBase__Data";

          # QUESTION: Should be in Shared too?
          "ChronoIndex" = "ChronoIndex";
          "Taxonomy" = "Taxonomy";
          "Taxonomy_hub" = "Taxonomy_hub";
          "Taxonomy_hub{current}" = "Taxonomy_hub{current}";
          "KnowledgeBase" = "KnowledgeBase";
          "KnowledgeBase_hub" = "KnowledgeBase_hub";
          "KnowledgeBase_hub{current}" = "KnowledgeBase_hub{current}";

          # More specific.
          "qmk" = "Shared/_configs/Keyboard__/ErgohavenVialQmk/keyboards/ergohaven/k02/keymaps/DeadlySquad13";
        } //
        # System-level configs.
        # - Temporary.
        builtins.mapAttrs (name: value: "/usr/local/etc/${value}") {
          "incoming.system-configs" = "";
        } //
        # - Permanent.
        builtins.mapAttrs (name: value: "/usr/local/dotfiles-/${value}") {
          "system-configs" = "_configs";
          "system-scripts" = "_scripts";
        } //
        # User-level configs.
        # - Temporary.
        builtins.mapAttrs (name: value: "/home/ds13/.local/etc/${value}") {
          "incoming.home-configs" = "";
        } //
        # - Permanent.
        builtins.mapAttrs (name: value: "/home/ds13/.local/dotfiles-/${value}") {
          "home-configs" = "_configs";
          "home-scripts" = "_scripts";
        } //
        # Projects
        builtins.mapAttrs (name: value: "/home/ds13/Projects/${value}") {
          # Namespaces.
          "ephemeral-projects" = "emphemeral-";
          "interim-projects" = "interim-";

          # Specific projects.
          "mlops" = "--educational/MlOps_course__Tasks";
        } //
        # # Shared Projects.
        builtins.mapAttrs (name: value: "/shared/soft-projects-/ds13/Projects/${value}") {
          "shared-projects" = "";
          "Programming_dotfiles.bootstrap" = "--personal/Programming_dotfiles.bootstrap";
        } //
        # # Shared Project Assets.
        builtins.mapAttrs (name: value: "/mnt/Project_assets/${value}") {
          "shared-project-assets" = "";
        }
      ) //
      # Non-bookmarks
      {
        "Projects/shared-" = /shared/soft-projects-/ds13/Projects;
        "Projects/shared-assets" = /mnt/Project_assets;
      }
    );
}
