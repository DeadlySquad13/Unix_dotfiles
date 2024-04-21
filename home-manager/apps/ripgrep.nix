{ pkgs, inputs, config, ... }:

{
  home.packages = with pkgs; [
    ripgrep
  ];
}
