{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "syncthing";
}
{
  services.syncthing = {
    enable = true;
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {
        "POCO X6 Pro 5G" = {id = "HC3AI3I-M5MX4QG-XK2GLZZ-XK3ATLW-3VRXKPR-VATN3Q3-UKUCPYJ-B77VEQK";};
        "@creamsoda" = {id = "EU6MIGT-GWHH4FB-AWEOFS3-F7QS552-JDDBNTM-YOXMAQC-CGMPR5F-NDTZAQK";};
      };
      folders = {
        "-secrets" = {
          path = "/shared/archive-resources-/Archive/YandexDisk/-secrets";
          id = "vgg7f-vdut5";
          devices = ["POCO X6 Pro 5G"];
        };
        "KnowledgeBase" = {
          path = "/home/ds13/.bookmarks/kbn";
          id = "tqoqm-gyfov";
          devices = ["POCO X6 Pro 5G" "@creamsoda"];
        };
        "CurrentTerm" = {
          path = "/shared/archive-resources-/Projects/CurrentTerm";
          id = "3jzjd-srmar";
          devices = ["POCO X6 Pro 5G"];
        };
        "denis-CurrentTerm" = {
          path = "/shared/archive-resources-/Projects/denis-/CurrentTerm";
          id = "3cp9p-5c7kw";
          devices = ["POCO X6 Pro 5G"];
        };
        "taskd" = {
          path = "/home/ds13/.taskd";
          id = "4r7wr-n7ei5";
          devices = ["POCO X6 Pro 5G"];
        };
      };
    };
  };
}
