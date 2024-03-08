{ pkgs, inputs, config, ... }:

{
  programs.neovim = {
    enable = true;

  };

  programs.taskwarrior = {
    enable = true;
  };

  home.packages = with pkgs; [
    taskwarrior-tui
    translate-shell
  ];
}
