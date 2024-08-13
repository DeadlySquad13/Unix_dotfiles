{ pkgs, config, lib, ... }:

# Everything else is already moved.
{
  imports =  
  [ 
    ../share.nix

    ../apps/nix.nix
    ../apps/home-manager.nix

    # ../apps/git.nix

    ../apps/flameshot.nix
    ../apps/invoke.nix
    ../apps/bash.nix
    ../apps/broot.nix
    ../apps/zoxide.nix
    ../apps/docker.nix

    # Cli (Quality of Life).
    ../apps/eza.nix
    ../apps/atuin.nix
    ../apps/blesh.nix
    ../apps/fzf.nix
    # ../apps/ranger.nix
    # ../apps/yabai.nix
    # ../apps/skhd.nix

    # ../apps/mattermost.nix
  ];

  programs = {
    # FIX: Nix wasn't enabled until sourced it manually.
    bash.bashrcExtra = 
      ''
        [[ -f /etc/bashrc ]] && . /etc/bashrc
      '';
  };

  /* Was needed for vivaldi.
   * nixpkgs.config = {
      allowUnsupportedSystem = true;
      allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
            "vivaldi"
        ];
  }; */
}
