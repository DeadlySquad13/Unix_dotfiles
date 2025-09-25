{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "skhd";
}
{
  services.skhd = {
    enable = true;

    skhdConfig = builtins.readFile /Users/apakalo/.config/skhd/skhdrc;
    # skhdConfig = ''
    #   alt - s : yabai -m window --focus west
    #   alt - t : yabai -m window --focus east
    #   alt - n : yabai -m window --focus south
    #   alt - m : yabai -m window --focus north
    # '';
  };
}
/*
References:
[@KeybaseArchWiki]: <https://wiki.archlinux.org/title/Keybase> 'Keybase - ArchWiki'
[z@KeybaseArchWiki]: <zotero://select/library/items/@/KeybaseArchWiki> 'Select in Zotero: Keybase - ArchWiki'
*/
