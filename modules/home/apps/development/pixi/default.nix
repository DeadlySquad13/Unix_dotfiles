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
  name = "pixi";
}
{

  # TODO: Fetch updates of flake from @salt.
  # home.packages = with pkgs; [
  #   pixi
  # ];
  # TODO: Ideally check our preferred shells and do for each...
  programs.bash = {
    bashrcExtra = /*bash*/ ''
      # Pixi completion.
      eval "$(pixi completion --shell bash)"
    '';
  };
}
