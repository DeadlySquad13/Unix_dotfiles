{ pkgs, inputs, config, ... }:

{
  home.packages = with pkgs; [
    qmk
  ];
}
