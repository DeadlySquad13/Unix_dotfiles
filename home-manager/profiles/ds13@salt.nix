{ config, lib, ... }:

{
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05";
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "ds13";
  home.homeDirectory = "/home/ds13";

  # TODO: Add autocomplete to names.
  imports = map (module: ../${module}.nix) (
    [
      "bookmarks"
    ] ++ (map (name: "apps/${name}")
    [
      # Nix related.
      "home-manager"
      "nix"

      # General.
      "numlockx"
      "keychain" # For easier ssh keys management.
      "unzip"
      "wezterm"
      "syncthing"
      "flatpak"

      #   Doesn't have service included. Most likely it should be enabled 'nix'
      # "way"
      # "udisks2"

      # Utilities.
      # - Cli level.
      "invoke"
      "broot"
      "fzf"
      "cht-sh"
      "thefuck"
      "bat"
      "eza"
      "zoxide"
      "nvimpager"
      "tree"
      # - X level.
      "flameshot"

      # Productivity
      "tmux"
      "uair"
      "smug"
      "taskwarrior"
      "taskwarrior-tui"

      # FIX: Doesn't detect gpu on Arch.
      # With yay it works, though. It also installed these packages alongside
      # maybe they were missing:
      # libdatachannel-0.20.3-2  libjuice-1.4.0-1  libsrtp-1:2.6.0-1  mbedtls-3.5.2-1  qt6-svg-6.7.0-1  rnnoise-1:0.2-1
      # obs-studio
      "vlc"
      "logseq"

      # Architecturing.
      "plantuml"

      # Development.
      "nodejs"
      "browser-sync" # Requires nodejs.
      "direnv"
      # # Base.
      # # # Git.
      "git"
      "lazygit"
      "gh" # GitHub cli.
      "glab" # GitLab cli.

      # # # Docker.
      "docker"

      # # Python.
      # pixi # Package manager (only on unstable yet).

      # General.
      "bash"
      "keepassxc"

      "ferdium"
      "telegram-desktop"

      "zathura"
      "zotero"

      "qbittorrent"

      "neovim"
      "ripgrep"
      # Specific.
      "qmk"
      "texlive"
      "pandoc"
    ])
  );

  # FIX: Doesn't seems to work.
  #
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
    CDPATH = "~/.bookmarks:/test";
  };

  programs = {
    bash.bashrcExtra = 
      ''
          # Pixi completion.
          eval "$(pixi completion --shell bash)"

          # Docker in rootless mode.
          export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      '';
  };
}
