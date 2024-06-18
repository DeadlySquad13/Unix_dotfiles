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
          "bash/history" = "Bash_history";
          "common-list-jupyter" = "Maxima_history";
          "mind.nvim" = "MindNvim";
          "nix/repl-history" = "Nix__Repl_history";
        }
      )
    );
}
