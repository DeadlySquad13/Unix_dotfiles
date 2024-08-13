{ ... }:

{
  programs.rofi = {
    enable = true;

    extraConfig = {
      modes = [
        "window"
        "drun"
        "run"
        "ssh"
        "combi"
      ];
    };
  };
}
