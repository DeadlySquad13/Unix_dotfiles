{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf;

  modules-cfg = config.lib.${namespace}.modules;
  cfg = modules-cfg.tools.ranger;
in
  {
    imports = [
      ./dev.nix
      ./stage.nix
    ];
  }
  // mkIf cfg.enabled {
    home.file = {
      # Prod.
      ".config/ranger/commands.py".source =
        pkgs.fetchFromGitHub {
          owner = "DeadlySquad13";
          repo = "Wsl2_dotfiles";
          rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
          hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
        }
        + "/stow_home/ranger/.config/ranger/commands.py";
    };

    programs.ranger = {
      enable = true;

      mappings = {
        "<Esc>" = "move left=1";
        # * Create.
        # - Directory.
        "cd" = "console mkdir%space";
        # - File.
        "cf" = "console touch%space";

        # Cd via zoxide.
        "j" = "console z%space";

        "r" = "console";
        "e" = "chain draw_possible_programs; console open_with%space";

        # Filter as you type (like leap keymap in NeoVim).
        "i" = "console scout -ftsea%space";

        # Moving next and previous tabs (like in Surfingkeys).
        "N" = "tab_move 1";
        "E" = "tab_move -1";

        # Making tabs actions a little bit more semantically similar to another
        # programs.
        "gc" = "tab_new";
        "gx" = "tab_close";

        # Next and previous search entry (like in NeoVim).
        "<Tab>" = "search_next";
        "<S-Tab>" = "search_next forward=False";

        # Remapping yank to "f".
        "fp" = "yank path";
        "fd" = "yank dir";
        "fn" = "yank name";
        "f." = "yank name_without_extension";
        "ff" = "copy";
        "fa" = "copy mode=add";
        "fr" = "copy mode=remove";
        "ft" = "copy mode=toggle";
        "fgg" = "eval fm.copy(dirarg=dict(to=0), narg=quantifier)";
        "fG" = "eval fm.copy(dirarg=dict(to=-1), narg=quantifier)";
        "fj" = "eval fm.copy(dirarg=dict(down=1), narg=quantifier)";
        "fk" = "eval fm.copy(dirarg=dict(up=1), narg=quantifier)";
        # - YankContent of the file / image.
        "fF" = "YankContent";

        "uf" = "uncut";

        # Remapping delete to "l".
        "lL" = "console delete";
        "ll" = lib.mkDefault "console trash";
        # - And mapping cut sub functions of a delete to n (like in NeoVim).
        "nn" = "cut";
        "na" = "cut mode=add";
        "nr" = "cut mode=remove";
        "nt" = "cut mode=toggle";
        "ngg" = "eval fm.cut(dirarg=dict(to=0), narg=quantifier)";
        "nG" = "eval fm.cut(dirarg=dict(to=-1), narg=quantifier)";
        "nj" = "eval fm.cut(dirarg=dict(down=1), narg=quantifier)";
        "nk" = "eval fm.cut(dirarg=dict(up=1), narg=quantifier)";

        "un" = "uncut";
      };

      plugins = [
        {
          name = "zoxide";
          src = builtins.fetchGit {
            url = "https://github.com/jchook/ranger-zoxide.git";
          };
        }
        {
          name = "ranger_devicons";
          src = builtins.fetchGit {
            url = "https://github.com/alexanderjeurissen/ranger_devicons";
          };
        }
      ];
      extraConfig = ''
        default_linemode devicons
      '';
    };
  }
