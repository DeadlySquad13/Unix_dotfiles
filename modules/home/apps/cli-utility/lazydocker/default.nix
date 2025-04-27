{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "lazydocker";
}
{
  home.packages = with pkgs; [
    lazydocker
  ];

  home.shellAliases = {
    # ld is already taken by system utility.
    lzd = "lazydocker";
  };
}
