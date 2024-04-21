{ pkgs, inputs, config, ... }:

{
  programs.bash = {
    enable = true;

    shellAliases = {
        i = "invoke --search-root ~/.bookmarks/shared-scripts";
    };

    bashrcExtra = 
        "[[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc";
  };

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
  };

  home.packages = with pkgs; [
    bash
  ];
}
