{
  lib,
  namespace,
  config,
  pkgs,
  ...
}: let
  HdnExtended_xorgLayout = pkgs.fetchFromGitHub {
    owner = "DeadlySquad13";
    repo = "Keyboard__HdnExtended_xorgLayout";
    rev = "f2bbe928a918c0601f53c85de6be0bff95015070";
    hash = "sha256-2JMKdAmc9Jf2llzCpXkY4zIvkRz4r8HYNbqlxsuo2AE=";
  }+ "/.Xkeymap.xkb";
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "xserver";
    name = "hdn";
  }
  {
    services.xserver = {
      xkb.layout = "us,ru";
      # xkbVariant = "workman,";
      # xkbOptions = "grp:win_space_toggle";
    };
  }
