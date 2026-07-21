# Used for sharing settings between home syncthing configurations. Must be
# explicitly imported.
{ lib }:
let
  availableDevices = {
    "POCO X6 Pro 5G" = {
      id = "HC3AI3I-M5MX4QG-XK2GLZZ-XK3ATLW-3VRXKPR-VATN3Q3-UKUCPYJ-B77VEQK";
    };
    "@salt" = {
      id = "MBUERHR-OBYJNZ4-UC4WXZK-XJHOQRF-UWTGL6U-6L3VGG6-ZANL3TT-MJB7RAK";
    };
    "@sugar" = {
      id = "GAY7RJA-JYHSVSZ-5IGMIAM-QJOBMWM-MN25PE4-K3MSF7Q-QPTGDAK-I42DIAS";
    };
    "@creamsoda" = {
      id = "EU6MIGT-GWHH4FB-AWEOFS3-F7QS552-JDDBNTM-YOXMAQC-CGMPR5F-NDTZAQK";
    };
  };
in
{
  # Usage:
  # `selectDevices ["@salt" "@creamsoda"]` produces:
  # ```nix
  # {
  #   "@sugar" = {
  #     id = "GAY7RJA-JYHSVSZ-5IGMIAM-QJOBMWM-MN25PE4-K3MSF7Q-QPTGDAK-I42DIAS";
  #   };
  #   "@creamsoda" = {
  #     id = "EU6MIGT-GWHH4FB-AWEOFS3-F7QS552-JDDBNTM-YOXMAQC-CGMPR5F-NDTZAQK";
  #   };
  # }
  # ```
  selectDevices = deviceNames: lib.genAttrs deviceNames (k: availableDevices.${k});

  folderIds = {
    KnowledgeBase = "tqoqm-gyfov";
    CurrentTerm = "3jzjd-srmar";
    denis-CurrentTerm = "3cp9p-5c7kw";
    taskd = "4r7wr-n7ei5";
    rut-Projects = "xtnmf-9ntus";
    rut-Projects_artifacts = "hr7sk-jvwjg";
    shared-Documents = "p9lcy-5seku";
    rutDocuments = "rut-Documents";
  };
}
