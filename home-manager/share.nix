{ config, lib, ... }:
{
  # TODO: Fix links with on empty system without existing link.
  home.file = builtins.mapAttrs
    (name: value: { source = config.lib.file.mkOutOfStoreSymlink value; })
    (
      lib.attrsets.concatMapAttrs (name: value: { ".local/share/${name}" = value; } )
      (
        builtins.mapAttrs (name: value: "/Users/aspakalo/.local/share-/${value}")
        {
          # Mapping .local/share/ dirs = to my local share
          "bash/history" = "Bash_history";
          "common-list-jupyter" = "Maxima_history";
          "mind.nvim" = "MindNvim";
          "nix/repl-history" = "Nix__Repl_history";
          "ranger" = "Ranger";
          "wezterm/repl-history" = "Wezterm__Repl_history";

          "nvim/auto_session" = "Nvim/auto_session";
          "nvim/project_nvim" = "Nvim/project_nvim";
          "nvim/sessions" = "Nvim/sessions";
          "nvim/spell" = "Nvim/spell";
          "nvim/view" = "Nvim/view";
          "nvim/undo" = "Nvim/undo";
          "nvim/telescope_history" = "Nvim/telescope_history";
        }
      )
    );
}
