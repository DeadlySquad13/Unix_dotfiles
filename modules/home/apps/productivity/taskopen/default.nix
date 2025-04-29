{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "taskopen";
}
{
  home.packages = with pkgs; [
    ds-omega.taskopen2
  ];

  home.file = {
    ".config/taskopen/taskopenrc".text = /*ini*/ ''
        [Actions]
        # note.regex = "^Note\\.(.*)"
        note.regex = "^Note"
        # For some reason $EDITOR is not defined...
        note.command = "nvim ~/.bookmarks/kbn/tasknotes-/$UUID.md"
        # note.command = "$EDITOR ~/.bookmarks/kbn/tasknotes-/$UUID.$LAST_MATCH"
      # vi:ft=ini
    '';
  };
}
