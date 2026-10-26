{
  lib,
  config,
  ...
}: let
  inherit (config.home) homeDirectory;
  shared = import ../../../../modules/home/services/syncthing/shared.nix {inherit lib;};
in
  # FIX: Infinite recursion caused by namespace.
  lib.ds-omega.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "syncthing";
  }
  {
    services.syncthing.settings = {
      devices = shared.selectDevices [
        "POCO X6 Pro 5G"
        # ../../../x86_64-linux/ds13@salt/syncthing/default.nix
        "@salt"
        "@sugar"
      ];
      folders = {
        "-secrets" = {
          path = "${homeDirectory}/Yandex.Disk.localized/-secrets";
          id = "vgg7f-vdut5";
          devices = ["@salt"];
        };
        "KnowledgeBase" = {
          path = "${homeDirectory}/.bookmarks/kbd";
          id = shared.folderIds.KnowledgeBase;
          devices = [
            "@sugar"
            "@salt"
          ];
        };
        "CurrentTerm" = {
          path = "${homeDirectory}/Bmstu__/CurrentTerm";
          id = shared.folderIds.CurrentTerm;
          devices = ["@sugar"];
        };
        "denis-CurrentTerm" = {
          path = "${homeDirectory}/Bmstu__/denis-/CurrentTerm";
          id = shared.folderIds.denis-CurrentTerm;
          devices = ["@sugar"];
        };
        "taskd" = {
          path = "${homeDirectory}/.taskd";
          id = shared.folderIds.taskd;
          devices = ["POCO X6 Pro 5G"];
        };

        "resources-books-exploring" = {
          path = "${homeDirectory}/resources-/-books/-exploring";
          id = "5uoke-wrnaf";
          devices = ["@sugar"];
        };
        "resources-books-creating" = {
          path = "${homeDirectory}/resources-/-books/-creating";
          id = "lw2rw-sfwcr";
          devices = ["@sugar"];
        };

        "rut-Projects" = {
          path = "${homeDirectory}/Projects";
          id = shared.folderIds.rut-Projects;
          devices = ["@salt"];
          # Project-local raw artifacts (mirrored into the centralized
          # `.artifact`). Must not be scanned by the bidirectional rut-Projects
          # folder — carried only by the simplex pair. `.local-artifacts` is
          # unanchored (project-anchored, any depth); `.artifacts--processed`
          # is root-anchored.
          ignorePatterns = [
            ".local-artifacts"
            "/.artifacts--processed"
          ];
        };
        "rut-Projects_artifacts" = {
          path = "${homeDirectory}/Projects/.artifact";
          id = shared.folderIds.rut-Projects_artifacts;
          devices = ["@salt"];
          type = "sendonly";
        };
        "rut-Projects_artifacts_processed" = {
          # Return direction @salt -> @creamsoda (processed review results).
          path = "${homeDirectory}/Projects/.artifacts--processed";
          id = shared.folderIds.rut-Projects_artifacts_processed;
          devices = ["@salt"];
          type = "receiveonly";
        };
        "rut-Documents" = {
          path = "${homeDirectory}/Documents";
          id = shared.folderIds.rut-Documents;
          devices = ["@salt"];
          # Project-local raw artifacts (mirrored into the centralized
          # `.artifacts`). Must not be scanned by the bidirectional rut-Documents
          # folder — carried only by the simplex pair. `.local-artifacts` is
          # unanchored (project-anchored, any depth); `.artifacts--processed`
          # is root-anchored.
          ignorePatterns = [
            ".local-artifacts"
            "/.artifacts--processed"
          ];
        };
        "rut-Documents_artifacts" = {
          # Raw direction @creamsoda -> @salt.
          path = "${homeDirectory}/Documents/.artifacts";
          id = shared.folderIds.rut-Documents_artifacts;
          devices = ["@salt"];
          type = "sendonly";
        };
        "rut-Documents_artifacts_processed" = {
          # Return direction @salt -> @creamsoda (processed artifacts).
          path = "${homeDirectory}/Documents/.artifacts--processed";
          id = shared.folderIds.rut-Documents_artifacts_processed;
          devices = ["@salt"];
          type = "receiveonly";
        };
      };
    };
  }
