{pkgs, ...}: {
  programs.bash = {
    enable = true;
    # Completion script was causing errors on shell startup because of `[ "$vars" ]`.
    enableCompletion = true;

    shellAliases = {
      # https://joshtronic.com/2021/05/23/unlock-user-after-too-many-failed-sudo-attempts/
      resetFailLock = "faillock --user $USER --reset";
    };

    # TODO: Move pixi to a separate layer.
    bashrcExtra = ''
      # Personal profile.
      [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc

      # Pixi completion.
      eval "$(pixi completion --shell bash)"
    '';
  };

  home.file = {
    # ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
    ".bash".source =
        pkgs.fetchFromGitHub {
          owner = "DeadlySquad13";
          repo = "Bash_config";
          rev = "dcba041e1a0ef183a6c9d8af138f7838a22cbb15";
          hash = "sha256-jIKemoaMlmrhCclVloNYwGN80w3DacYBVW5Lv5JFHuM=";
        }
        + "/stow_home/ranger/.config/ranger/commands.py";
  };

  # TODO: Move all these to layer.
  # imports = [
  #   ../complete-alias/default.nix
  # ];
}
