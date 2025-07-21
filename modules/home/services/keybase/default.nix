{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.${namespace}) source;
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "services";
    name = "keybase";
  }
  {
    services.keybase = {
      enable = true;
    };

    services.kbfs = {
      enable = true;
      # Relative to HOME.
      mountPoint = "shared/-cloud/keybase-";
    };

    # `fusermount: exec: "fusermount": executable file not found in $PATH`
    # home-manager expects it at a certain location `/run/wrappers/bin/fusermount`
    # https://github.com/nix-community/home-manager/blob/206ed3c71418b52e176f16f58805c96e84555320/modules/services/kbfs.nix#L63
    # REFACTOR: Remove hardcode of locations. Maybe even install fusermount via Nix.
    home.file."/run/wrappers/bin/fusermount" = source {
      inherit config;
      get-path = _p: "/usr/bin/fusermount";
      out-of-store = true;
    };
  }
/*
References:
[@KeybaseArchWiki]: <https://wiki.archlinux.org/title/Keybase> 'Keybase - ArchWiki'
[z@KeybaseArchWiki]: <zotero://select/library/items/@/KeybaseArchWiki> 'Select in Zotero: Keybase - ArchWiki'
*/
