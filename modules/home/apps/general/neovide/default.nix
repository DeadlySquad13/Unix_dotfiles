{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "general";
  name = "neovide";
}
{
  programs.neovide = {
    enable = true;
    package = pkgs.ds-omega.gl-neovide;
  };

  # TODO: Add mkIfDevEnabled.
  programs.bash = {
    sessionVariables = {
      GUI_EDITOR = "gvi-stage";
    };
  };

  # https://github.com/neovide/neovide/blob/084db1b1412d4975d74a781051c0122e53bb0332/assets/neovide.desktop
  xdg.desktopEntries.neovide = {
    name = "Neovide";
    type = "Application";
    exec = "neovide %F";
    icon = "neovide";
    # keywords = [
    #   "Text"
    #   "Editor"
    # ];
    categories = [
      "Utility"
      "TextEditor"
    ];
    comment = "No Nonsense Neovim Client in Rust";
    mimeType = [
      "text/english"
      "text/plain"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-moc"
      "text/x-pascal"
      "text/x-tcl"
      "text/x-tex"
      "application/x-shellscript"
      "text/x-c"
      "text/x-c++"
    ];
    # startupNotify = "true";
    # startupWMClass = "neovide";
  };

  xdg.mimeApps = {
    enable = true;

    # Default applications (what opens when no association exists or user chooses default)
    defaultApplications = {
      "text/plain" = "neovide.desktop";
      "text/html" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      "x-scheme-handler/about" = "vivaldi-stable.desktop";
      "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "x-scheme-handler/logseq" = "Logseq.desktop";
    };

    # Additional associations (added to the list of possible apps, not necessarily default)
    associations.added = {
      "application/epub+zip" = "zathura.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };

  home.shellAliases = {
    gvi = "gl-neovide";
    # TODO: Add mkIfDevEnabled.
    gvi-stage = "NVIM_APPNAME=nvim-stage gl-neovide";
    gvi-dev = "NVIM_APPNAME=nvim-dev gl-neovide";
  };
}
