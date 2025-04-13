{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "neovide";
  # Needs gl- wrapper to properly work on linux.
  extraPredicate = lib.${namespace}.mkIfDarwin;
}
{
  home.packages = with pkgs; [
    neovide
  ];

  home.shellAliases = {
    gvi = "neovide &";
    # TODO: Add mkIfDevEnabled.
    gvi-stage = "NVIM_APPNAME=nvim-stage neovide &";
    gvi-dev = "NVIM_APPNAME=nvim-dev neovide &";
  };
}
