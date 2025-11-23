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
    category = "productivity";
    name = "taskopen";
  }
  {
    home.packages = with pkgs; [
      ds-omega.taskopen2
    ];

    # Taskopen-specific aliases.
    # INFO: Usage: `task <alias> <taskId>` (not as usual
    # `task <taskId> <alias>`!)
    programs.taskwarrior.config.alias = {
      addnote = "execute ${pkgs.ds-omega.taskopen-scripts}/bin/addnote";
      anote = "execute ${pkgs.ds-omega.taskopen-scripts}/bin/addnote";

      editnote = "execute ${pkgs.ds-omega.taskopen2}/bin/taskopen";
      enote = "execute ${pkgs.ds-omega.taskopen2}/bin/taskopen";
    };

    home.file = {
      ".config/taskopen/taskopenrc".text = # ini
        ''
          [General]
          taskbin=task
          taskargs
          # DEFAULT: no_annotation_hook="addnote $ID"
          no_annotation_hook="${pkgs.ds-omega.taskopen-scripts}/bin/addnote $ID"
          task_attributes="priority,project,tags,description"
          --sort:"urgency-,annot"
          --active-tasks:"+PENDING"
          EDITOR=nvim-dev
          path_ext=${pkgs.ds-omega.taskopen2}/share/taskopen/scripts
          [Actions]
          files.target=annotations
          files.labelregex=".*"
          files.regex="^[\\.\\/~]+.*\\.(.*)"
          files.command="xdg-open $FILE"
          files.modes="batch,any,normal"
          notes.target=annotations
          notes.labelregex=".*"
          notes.regex="^Notes(\\..*)?"
          # $LAST_MATCH is the match group in `notes.regex` (file extension).
          # DEFAULT: notes.command="""editnote ~/.bookmarks/kbn/tasknotes-/$UUID$LAST_MATCH "$TASK_DESCRIPTION" $UUID"""
          notes.command="""${pkgs.ds-omega.taskopen-scripts}/bin/editnote ~/.bookmarks/kbn/tasknotes-/$UUID$LAST_MATCH "$TASK_DESCRIPTION" $UUID"""
          notes.modes="batch,any,normal"
          url.target=annotations
          url.labelregex=".*"
          url.regex="((?:www|http).*)"
          url.command="xdg-open $LAST_MATCH"
          url.modes="batch,any,normal"
          # vi:ft=ini
        '';
    };
  }
