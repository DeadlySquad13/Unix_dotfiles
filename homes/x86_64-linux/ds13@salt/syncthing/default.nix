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
        "@creamsoda"
      ];
      folders = {
        "-secrets" = {
          path = "/shared/archive-resources-/Archive/YandexDisk/-secrets";
          id = "vgg7f-vdut5";
          devices = ["POCO X6 Pro 5G"];
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

        "rut-Projects" = {
          path = "/zsalt/shared-/@creamsoda/Projects";
          id = shared.folderIds.rutProjects;
          devices = ["@creamsoda"];
          ignorePatterns = [
            # Scratchpad, relevant only on @salt for now so no need to sync.
            "/ai-"
          ];
        };
        "rut-Documents" = {
          path = "/zsalt/shared-/@creamsoda/Documents";
          id = shared.folderIds.rutDocuments;
          devices = ["@creamsoda"];
        };
      };
    };
  }
