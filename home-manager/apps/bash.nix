{ pkgs, inputs, config, ... }:

{
  programs.bash = {
    enable = true;

    shellAliases = {
        i = "invoke --search-root ~/.bookmarks/shared_scripts";
    };

    bashrcExtra = 
        "[[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc";
  };


  home.packages = with pkgs; [
    bash
  ];
}
