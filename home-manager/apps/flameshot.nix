{ pkgs, ... }:

{
  home.packages = with pkgs; [
    flameshot
  ];
  home.file = {
    ".config/flameshot" = {
      source = ''
        [General]
        contrastOpacity=188

        [Shortcuts]
        TAKE_SCREENSHOT=F13
        '';
    };
  };
}
