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
          id = shared.folderIds.rutProjects;
          devices = ["@salt"];
        };
        "rut-Documents" = {
          path = "${homeDirectory}/Documents";
          id = shared.folderIds.rutDocuments;
          devices = ["@salt"];
        };
      };
    };
  }
