{ config, lib, ... }:
{
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
          "shared-configs" = "Shared/Configs";
          "shared-scripts" = "Shared/_scripts";

          # ?: Should be in Shared too?
          "kbd" = "Resources/KnowledgeBase__Data";

          # More specific.
          "qmk" = "Shared/Configs/Keyboard__/ErgohavenVialQmk/keyboards/ergohaven/k02/keymaps/DeadlySquad13";
        } //
        # # Projects
        builtins.mapAttrs (name: value: "/home/ds13/Projects/${value}") {
          "mlops" = "--educational/MlOps_course__Tasks";
        } //
        # # Shared Projects
        builtins.mapAttrs (name: value: "/shared/soft-projects-/ds13/Projects/${value}") {
          "shared-projects" = "";
          "Programming_dotfiles.bootstrap" = "--personal/Programming_dotfiles.bootstrap";
        }
      ) //
      {
        "Projects/shared-" = /shared/soft-projects-/ds13/Projects;
      }
    );
}
