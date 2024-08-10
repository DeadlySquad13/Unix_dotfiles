{pkgs, ...}: {
  home.packages = with pkgs; [
    ds-omega.taskopen2
  ];

  home.file = {
    ".config/taskopen/taskopenrc".text = ''
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
