{...}: {
  programs.bash = {
    enable = true;
    # Completion script was causing errors on shell startup because of `[ "$vars" ]`.
    enableCompletion = true;

    shellAliases = {
      # https://joshtronic.com/2021/05/23/unlock-user-after-too-many-failed-sudo-attempts/
      resetFailLock = "faillock --user $USER --reset";
    };

    bashrcExtra = ''
      # Personal profile.
      [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc
    '';
  };

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
  };

  # TODO: Move all these to layer.
  # imports = [
  #   ../complete-alias/default.nix
  # ];
}
