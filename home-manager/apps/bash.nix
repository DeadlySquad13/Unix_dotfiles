{ ... }:

{
  programs.bash = {
    enable = true;
    # Completion script was causing errors on shell startup because of `[ "$vars" ]`.
    enableCompletion = true;

    bashrcExtra = 
      ''
        # For environment variables.
        [[ -f ~/.profile ]] && . ~/.profile

        # Personal profile.
        [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc
      '';
  };

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
  };
}
