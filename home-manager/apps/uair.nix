{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Extensible pomodoro timer.
    uair
  ];
}
