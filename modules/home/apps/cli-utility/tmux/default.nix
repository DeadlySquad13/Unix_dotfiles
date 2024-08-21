{ pkgs, ... }:

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
    ".config/tmux/old.conf".source =
        pkgs.fetchFromGitHub {
          owner = "DeadlySquad13";
          repo = "Wsl2_dotfiles";
          rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
          hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
        }
        + "/stow_home/tmux/.tmux.conf";
  };
}
