{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "gui-utility";
  name = "ranger-default-opener";
}
{
  # The source files live in the scripts repo and are exposed through bookmarks.
  home.file.".local/share/applications/xranger.desktop".source =
    config.lib.file.mkOutOfStoreSymlink
    "/usr/local/dotfiles-/_scripts/Desktop__RangerDefaultOpener/xranger.desktop";

  home.file.".local/bin/open-tui".source =
    config.lib.file.mkOutOfStoreSymlink
    "/usr/local/dotfiles-/_scripts/Desktop__RangerDefaultOpener/open-tui";

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "xranger.desktop";
    };
  };
}
