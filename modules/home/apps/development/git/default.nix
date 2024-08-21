{ pkgs, ... }:

{
  home.file = {
    ".gitconfig".source = 
        pkgs.fetchFromGitHub {
          owner = "DeadlySquad13";
          repo = "Wsl2_dotfiles";
          rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
          hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
        }
        + "/stow_home/git/.gitconfig";
    ".config/git/.global_gitignore".source =
        pkgs.fetchFromGitHub {
          owner = "DeadlySquad13";
          repo = "Wsl2_dotfiles";
          rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
          hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
        }
        + "/stow_home/git/.global_gitignore";
  };

  home.packages = with pkgs; [
    git
  ];
}
