{
  lib,
  namespace,
  config,
  ...
}: let
  shared = import ../../../../modules/home/services/syncthing/shared.nix {inherit lib;};
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "syncthing";
  }
  {
    services.syncthing.settings = {
      devices = shared.selectDevices [
        "POCO X6 Pro 5G"
        # ../../../aarch64-darwin/apakalo@creamsoda/syncthing/default.nix
        "@creamsoda"
      ];
      folders = {
        "-secrets" = {
          path = "/shared/archive-resources-/Archive/YandexDisk/-secrets";
          id = "vgg7f-vdut5";
          devices = [
            "POCO X6 Pro 5G"
            "@creamsoda"
          ];
        };
        "KnowledgeBase" = {
          path = "/home/ds13/.bookmarks/kbd";
          id = shared.folderIds.KnowledgeBase;
          devices = [
            "POCO X6 Pro 5G"
            "@creamsoda"
          ];
        };
        "CurrentTerm" = {
          path = "/shared/archive-resources-/Projects/CurrentTerm";
          id = shared.folderIds.CurrentTerm;
          devices = ["POCO X6 Pro 5G"];
        };
        "denis-CurrentTerm" = {
          path = "/shared/archive-resources-/Projects/denis-/CurrentTerm";
          id = shared.folderIds.denis-CurrentTerm;
          devices = ["POCO X6 Pro 5G"];
        };
        "taskd" = {
          path = "/home/ds13/.taskd";
          id = shared.folderIds.taskd;
          devices = ["POCO X6 Pro 5G"];
        };

        # TODO: Currently should work only on @salt. May be neeed from within
        # Wsl on @pepper but not yet.
        "resources-book-leisuring" = {
          path = "/shared/archive-resources-/Resources/-books/-leisuring";
          id = "arfqd-gwsgl";
          devices = ["POCO X6 Pro 5G"];
        };

        # Doesn't include gallery albums, see Pictures.
        "Camera@PocoX6Pro5G" = {
          path = "/shared/archive-resources-/Archive/Backup/_media/PocoX6Pro5G";
          id = "2311drk48g_5v75-photos";
          devices = ["POCO X6 Pro 5G"];
        };

        # Stores pictures and photos by app. Including gallery albums too.
        "Pictures@PocoX6Pro5G" = {
          path = "/shared/archive-resources-/Archive/Backup/_media/PocoX6Pro5G__Pictures";
          id = "hr3ti-vl4qo";
          devices = ["POCO X6 Pro 5G"];
        };
        
        "Dictionaries" = {
          path = "/shared/archive-resources-/Archive/Installers/Dictionaries";
          id = "tva41-8zxxx";
          devices = ["POCO X6 Pro 5G"];
        };

        "shared-Documents" = {
          path = "/shared/archive-resources-/Archive/YandexDisk/Documents";
          id = shared.folderIds.shared-Documents;
          devices = ["POCO X6 Pro 5G"];
        };
        "Interim" = {
          path = "/shared/archive-resources-/Archive/YandexDisk/Interim";
          devices = ["POCO X6 Pro 5G"];
        };

        "rut-Projects" = {
          path = "/zsalt/shared-/@creamsoda/Projects";
          id = shared.folderIds.rut-Projects;
          devices = ["@creamsoda"];
          ignorePatterns = [
            # Scratchpad, relevant only on @salt for now so no need to sync.
            "/ai-"
            # Project-local raw artifacts (mirrored into the centralized
            # `.artifact`). Must not be scanned by the bidirectional rut-Projects
            # folder — carried only by the simplex pair. `.local-artifacts` is
            # unanchored (project-anchored, any depth); `.artifacts--processed`
            # is root-anchored.
            ".local-artifacts"
            "/.artifacts--processed"
          ];
        };
        "rut-Projects_artifacts" = {
          path = "/zsalt/shared-/@creamsoda/Projects/.artifact";
          id = shared.folderIds.rut-Projects_artifacts;
          devices = ["@creamsoda"];
          type = "receiveonly";
        };
        "rut-Projects_artifacts_processed" = {
          # Return direction @salt -> @creamsoda (processed review results).
          path = "/zsalt/shared-/@creamsoda/Projects/.artifacts--processed";
          id = shared.folderIds.rut-Projects_artifacts_processed;
          devices = ["@creamsoda"];
          type = "sendonly";
        };
        "rut-Documents" = {
          path = "/zsalt/shared-/@creamsoda/Documents";
          id = shared.folderIds.rut-Documents;
          devices = ["@creamsoda"];
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
          path = "/zsalt/shared-/@creamsoda/Documents/.artifacts";
          id = shared.folderIds.rut-Documents_artifacts;
          devices = ["@creamsoda"];
          type = "receiveonly";
        };
        "rut-Documents_artifacts_processed" = {
          # Return direction @salt -> @creamsoda (processed artifacts).
          path = "/zsalt/shared-/@creamsoda/Documents/.artifacts--processed";
          id = shared.folderIds.rut-Documents_artifacts_processed;
          devices = ["@creamsoda"];
          type = "sendonly";
        };
      };
    };
  }
