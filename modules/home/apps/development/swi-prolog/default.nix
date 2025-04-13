{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "swi-prolog";
}
{

  # FIX: For some reason doesn't work, throws "error: undefined variable
  # 'swi-prolog"
  # home.packages = with pkgs; [
  #   swi-prolog
  # ];
}
