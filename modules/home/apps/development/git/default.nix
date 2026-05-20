{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
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
        rev = "8bdb15f577539b9ef1df65a0d7d35f23ca5a7e6e";
        hash = "sha256-aEz9Vv0mW0sqCwjUTPJnr59Z4i30WUXHgpTv81C/x0I=";
      }
      + "/stow_home/git/.global_gitignore";
  };
  programs.git = {
    enable = true;
    settings = {
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
        rebase = true;
      };
      alias = {
        hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        c = "clone";
        # - Add all.
        aa = "add -A";
        co = "checkout";
        sw = "switch";
        br = "branch";
        br-current = "branch --show-current";
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
