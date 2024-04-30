{ ... }:

{
  programs.bash = {
    enable = true;
    # Completion script was causing errors on shell startup because of `[ "$vars" ]`.
    enableCompletion = true;

    shellAliases = {
        i = "invoke --search-root ~/.bookmarks/shared-scripts";
    };

    bashrcExtra = 
      ''
        [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc
      '';
  };

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
  };
}
