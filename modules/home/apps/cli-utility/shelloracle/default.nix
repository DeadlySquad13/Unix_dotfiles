{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
# TODO: Needs to be packaged or installed via pipx.
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "shelloracle";
}
{
  programs.bash = {
    bashrcExtra = ''
      # Shelloracle.
      [ -f ~/.shelloracle.bash ] && . ~/.shelloracle.bash
    '';
  };

  home.file = {
    ".shelloracle.bash".source = builtins.fetchurl {
      # https://github.com/djcopley/ShellOracle/blob/16535e262ac7a3379bc5fa56426f225bb83da4ff/src/shelloracle/shell/shelloracle.bash
      url = "https://raw.githubusercontent.com/djcopley/ShellOracle/16535e262ac7a3379bc5fa56426f225bb83da4ff/src/shelloracle/shell/shelloracle.bash";
    };

    ".shelloracle/config.toml".source = ./config-${builtins.currentSystem}.toml;
  };

  home.packages = with pkgs; [
    # ds-omega.shelloracle
    pipx
  ];
}
