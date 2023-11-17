{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "ds13";
  home.homeDirectory = "/home/ds13";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # neovim
    xclip

    #   Doesn't have service included. Most likely it should be enabled 'nix'
    # way.
    # udisks2

    # pkgs.wezterm
    plantuml
    qmk
    ripgrep

    git
    lazygit
    gh # GitHub cli

    keepassxc

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    ".config/nvim".source = ~/.bookmarks/shared_configs/NeoVim_config;

    # # xdg home should be set to "$HOME/.config", otherwise wezterm will look
    # in another location.
    ".config/wezterm".source = ~/.bookmarks/shared_configs/WezTerm_config;

    ".bash".source = ~/.bookmarks/shared_configs/Bash_config;

    ".gitconfig".source = ~/.bookmarks/shared_configs/Wsl2_dotfiles/stow_home/git/.gitconfig;
    ".config/lazygit".source = ~/.bookmarks/shared_configs/Wsl2_dotfiles/stow_home/lazygit/.config/lazygit;

    # Not working unfortunately... It seems that left part can't start with '/'.
    # "/usr/local/share/fonts/Iosevka".source = ~/.bookmarks/shared-fonts;
    
    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  } // # Bookmarks.
  builtins.mapAttrs
      (name: value: { source = config.lib.file.mkOutOfStoreSymlink value; })
      {
        ".bookmarks/config" = ~/.config;
        ".bookmarks/shared_configs" = "/shared/archive&resources-/Shared/Configs";
        ".bookmarks/shared_scripts" = "/shared/archive&resources-/Shared/_scripts";
      };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/ds13/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    # CDPATH = "~/.bookmarks:/mnt/e";
  };

  programs = {
      # Let Home Manager install and manage itself.
      home-manager.enable = true;

      bash = {
        enable = true;

        shellAliases = {
            i = "invoke --search-root ~/.bookmarks/shared_scripts";
        };

        bashrcExtra = 
            "[[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc";
      };
  };

  # Seems to work only on NixOs?
  # environment.etc = {
  #   nanorc = {
  #       text = ''
  #           test
  #       '';
  #   };
  # };
}
