{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "git";
}
{
  home.file = {
    # ".gitconfig".source =
      # pkgs.fetchFromGitHub {
      #   owner = "DeadlySquad13";
      #   repo = "Wsl2_dotfiles";
      #   rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
      #   hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
      # }
      # + "/stow_home/git/.gitconfig";
    ".config/git/.global_gitignore".source =
      pkgs.fetchFromGitHub {
        owner = "DeadlySquad13";
        repo = "Wsl2_dotfiles";
        rev = "fa02f0aa6eca98b39a13448a73003083d246b37d";
        hash = "sha256-tg1VxLIgVfWK+vChX278p/4KvSPJfxY0f9wH3MJJ7Qo=";
      }
      + "/stow_home/git/.global_gitignore";

    "Projects/--professional/Rutube__/rutube_gitconfig.inc".text = ''
      [user]
        name = Пакало Александр
        email = apakalo@rutube.ru
    '';
  };
  programs.git = {
    enable = true;
    extraConfig = {
      core = {
        autocrlf = "input";
        excludesfile = "~/.config/git/.global_gitignore";
        ignorecase = false;
      };

      user = {
        name = "DeadlySquad13";
        email = "46250621+DeadlySquad13@users.noreply.github.com";
      };

      init = {
        templateDir = "~/.git-template";
        defaultBranch = "main";
      };
      safe = {
        directory = "*";
      };
      pull = {
        rebase = false;
      };
    };

    aliases = {
      hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
      c = "clone";
      # - Add all.
      aa = "add -A";
      co = "checkout";
      sw = "switch";
      br = "branch";
      st = "status";
      cm = "commit -m";
      pl = "pull";
      ps = "push";
      # - Push head.
      psh = "push -u origin HEAD";
      unstage = "restore --staged";
      # - Perform mixed reset.
      unstage-all = "reset HEAD --";
      # - Show config option scope (local, global...), origin (file) and current value.
      show-option-origin = "config --show-origin --show-scope --get-all";
    };

    includes = let 
      rutube-config = {
          user = {
            name = "Пакало Александр";
            email = "apakalo@rutube.ru";
          };
        };
      in [
      {
        contents = rutube-config;
        condition = "hasconfig:remote.*.url:https://gitlab.rutube.ru/**";
      }
      {
        contents = rutube-config;
        condition = "hasconfig:remote.*.url:git@gitlab.rutube.ru:*/**";
      }
      # Folder specific settings. Works only with git folders (doesn't work with
      # normal folders and worktrees).
      {
        contents = rutube-config;
        condition = "gitdir:~/Projects/--professional/Rutube__/";
      }
    ];
  };
}
