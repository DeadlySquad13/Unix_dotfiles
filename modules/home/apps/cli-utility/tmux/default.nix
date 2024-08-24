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
  name = "tmux";
}
{
  programs.tmux = {
    enable = true;

    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.resurrect
    ];

    extraConfig = "source ~/.config/tmux/old.conf";
  };

  # TODO: Configure properly via nix: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.tmux.enable
  home.file = {
    ".config/tmux/old.conf".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/tmux/.tmux.conf;
  };
}
