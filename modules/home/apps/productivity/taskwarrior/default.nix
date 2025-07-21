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
  name = "taskwarrior";
}
{
  programs.taskwarrior = {
    enable = true;

    package = pkgs.taskwarrior2;

    # Files
    dataLocation = "~/.task";
    # colorTheme = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/taskwarrior/deadly-solarized-light.theme;
    colorTheme =
      pkgs.fetchFromGitHub {
        owner = "DeadlySquad13";
        repo = "Wsl2_dotfiles";
        rev = "fa02f0aa6eca98b39a13448a73003083d246b37d";
        hash = "sha256-tg1VxLIgVfWK+vChX278p/4KvSPJfxY0f9wH3MJJ7Qo=";
      }
      + "/stow_home/taskwarrior/deadly-solarized-light";

    extraConfig =
      /*
      ini
      */
      ''
        # Default context.
        context=manual
      '';

    config = {
      # Contexts.
      context = {
        # Bugwarrior entities add custom UDAs.
        all = "id.any:";
        # manual = "-UDA";
        manual = "logsequuid.none:";
        logseq = "logsequuid.any:";

        side = "+side";
        personal = "project:PrX";
        soft = "+soft";
        work = "project:OGP or +work";
        lessons = "+lessons";

        # By groups of projects.
        fs = "project:fs or +filesystem";
        infofield = "project:InfoField or project:kbn or project:kbd";
        music-fs = "project:MusicLibrary or project:MusicDownload";
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
        # Overdue or near due date.
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

      # Sync.
      taskd = let
        taskdRootDir = "${config.home.homeDirectory}/.taskd";
      in {
        certificate = "${taskdRootDir}/Deadly_Squad13.cert.pem";
        key = "${taskdRootDir}/Deadly_Squad13.key.pem";
        ca = "${taskdRootDir}/ca.cert.pem";
        server = "46.8.19.152:53589";
        credentials = "Public/Deadly Squad13/6a44ae0c-f770-404b-8239-362afec3e867";
        trust = "ignore hostname";
      };
    };
  };

  # TODO: Move into layer.
  # imports = [
  #   ../taskopen/default.nix
  # ];

  # TODO: Move into layer.
  # REFACTOR: Move taskwarrior aliases from bashrc to here.
  # Must guarantee then than all Unix systems are nix based. Otherwise alias
  # will be lost.
  programs.bash = {
    bashrcExtra =
      /*
      bash
      */
      ''
        complete -F _complete_alias t
        complete -F _complete_alias ta
        complete -F _complete_alias taStep
        complete -F _complete_alias tL
        complete -F _complete_alias tA
      '';
    # https://www.reddit.com/r/taskwarrior/comments/uvwqlz/share_your_aliases/
    shellAliases = {
      ta = "task add";
      # Task add step to the algorithm.
      # For example, with this, you can chain tasks, so each depends on the one before it. Then you can do:
      # tAddStep get bag
      # tAddStep open door
      # tAddStep go down stairs
      # tAddStep get shopping
      #
      #   In this case, getting shopping depends on opening your door, so the door
      # receives a higher priority, and you'll get a warning if you try to get down
      # the stairs without your shopping bag.
      taStep = "task add dep:\"$(task +LATEST uuids)\"";
      tL = "task +LATEST";
      tA = "task +ACTIVE";
    };
  };
}
