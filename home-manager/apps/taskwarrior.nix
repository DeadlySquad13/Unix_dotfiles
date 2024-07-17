{...}: {
  programs.taskwarrior = {
    enable = true;

    # Files
    dataLocation = "~/.task";
    colorTheme = /shared/archive-resources-/Shared/Configs/Wsl2_dotfiles/stow_home/taskwarrior/deadly-solarized-light.theme;

    config = {
      # Contexts.
      context = {
        side = "+side";
        personal = "project:PrX";
        soft = "+soft";
        work = "project:OGP or +work";
        fs = "project:fs";
        KB = "project:personal.KB";
        lessons = "+lessons";
      };

      # Aliases.
      alias = {
        modify = "mod";
        project = "pro";
        depends = "dep";
        priority = "pri";
        annotate = "ann";
      };

      # Urgency.
      urgency = {
        uda = {
          priority = {
            # * Priority.
            H.coefficient = 6.0;
            M.coefficient = 3.9;
            L.coefficient = -1.8;
          };
        };

        # * Time.
        # overdue or near due date.
        due.coefficient = 12.0;
        scheduled.coefficient = 5.0;
        active.coefficient = 4.0;
        age.coefficient = 2.0;
        waiting.coefficient = -3.0;

        # - Dependency.
        blocked.coefficient = -5.0;
        blocking.coefficient = 8.0;

        # * Specificity.
        annotations.coefficient = 1.0;

        # - Tags.
        tags.coefficient = 1.0;
        user = {
          tag = {
            next.coefficient = 15.0;
            # Enforcing 50 % time working and 50 % time learning policy.
            work.coefficient = 5.0;
            lessons.coefficient = 3.0;
            # Sync and backup are important.
            sync.coefficient = 5.0;
          };
          project = {
            # However, while we are in university, it's better to finish it properly.
            Bmstu.coefficient = 5.0;
            # Sorting junk on computer is useful but never requires urgency.
            fs.coefficient = -3.0;
            # In most cases something related to system should be done as quick as possible.
            sys.coefficient = 5.0;
          };
        };

        # - Projects.
        project.coefficient = 1.0;
      };
      # context=soft

      # Sync.
      taskd = {
        certificate = "/home/ds13/.taskd/Deadly_Squad13.cert.pem";
        key = "/home/ds13/.taskd/Deadly_Squad13.key.pem";
        ca = "/home/ds13/.taskd/ca.cert.pem";
        server = "46.8.19.152:53589";
        credentials = "Public/Deadly Squad13/6a44ae0c-f770-404b-8239-362afec3e867";
        trust = "ignore hostname";
      };
    };
  };

  # home.file = {
  #   ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
  # };
}
