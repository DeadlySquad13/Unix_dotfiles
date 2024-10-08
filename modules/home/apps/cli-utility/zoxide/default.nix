{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "zoxide";
}
{
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;

    # https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#configuration
    options = [
      "--cmd j"
    ];
  };
}
