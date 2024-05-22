{ pkgs, config, lib, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "aspakalo";
  home.homeDirectory = "/Users/aspakalo";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05";

  imports =  
  [ 
    ../apps/nix.nix
    ../apps/home-manager.nix

    ../apps/flameshot.nix
    ../apps/invoke.nix
    ../apps/bash.nix
    ../apps/broot.nix
    ../apps/zoxide.nix
    ../apps/docker.nix

    # Cli (Quality of Life).
    ../apps/eza.nix
  ];

  home.file = {
    # TODO: Move from stow to the structure similar to ds13@salt bookmarks.
    ".bash".source = lib.mkForce ~/dotfiles/stow_home/bash/.bash;
  } // # Bookmarks.
  builtins.mapAttrs
      (name: value: { source = config.lib.file.mkOutOfStoreSymlink value; })
      (
        lib.attrsets.concatMapAttrs (name: value: { ".bookmarks/${name}" = value; } )
        ({
          "config" = ~/.config;
          "kbd" = ~/KnowledgeBase__Data;
          "projects" = "/Users/aspakalo/Projects";
          "shared-scripts" = ~/shared-scripts;
          # "shared-configs" = ~/shared-configs;
        } //
        # More specific.
        # # Projects
        builtins.mapAttrs (name: value: "/Users/aspakalo/Projects/${value}") {
          # Namespaces.
          "ephemeral-projects" = "ephemeral-";
          "interim-projects" = "interim-";

          # Specific projects.
          "lp" = "logistic-platform";
          "shepherd" = "shepherd";
          "kit" = "main-ui-kit";
          "@kit" = "main-ui-kit/packages";
          "@components" = "main-ui-kit/packages/components";
          "kit2" = "main-ui-kit2";
          "@kit2" = "main-ui-kit2/packages";
          "@components2" = "main-ui-kit2/packages/components";
        })
      );

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
