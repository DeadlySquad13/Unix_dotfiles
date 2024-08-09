{ ... }:

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
