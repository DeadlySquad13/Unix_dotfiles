{ pkgs, ... }:

{
  home.packages = with pkgs; [
    flameshot
  ];
  home.file = {
    ".config/flameshot/flameshot.ini" = {
      text = ''
        [General]
        contrastOpacity=188
        startupLaunch=true

        [Shortcuts]
        TAKE_SCREENSHOT=F13
        '';
    };
  };
}
