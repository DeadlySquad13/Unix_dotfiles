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
  name = "thefuck";
}
{
  # TODO: Change to pay-respects?
  # home.packages = with pkgs; [
  #   thefuck
  # ];

  # programs.bash = {
  #   bashrcExtra = /*bash*/ ''
  #     eval $(thefuck --alias pls)
  #   '';
  # };
}
