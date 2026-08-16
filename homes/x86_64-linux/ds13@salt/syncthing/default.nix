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

        "Camera@PocoX6Pro5G" = {
          path = "/shared/archive-resources-/Archive/Backup/_media/PocoX6Pro5G";
          id = "2311drk48g_5v75-photos";
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
          ];
        };
        "rut-Projects_artifacts" = {
          path = "/zsalt/shared-/@creamsoda/Projects/.artifact";
          id = shared.folderIds.rut-Projects_artifacts;
          devices = ["@creamsoda"];
          type = "receiveonly";
        };
        "rut-Documents" = {
          path = "/zsalt/shared-/@creamsoda/Documents";
          id = shared.folderIds.rutDocuments;
          devices = ["@creamsoda"];
        };
      };
    };
  }
