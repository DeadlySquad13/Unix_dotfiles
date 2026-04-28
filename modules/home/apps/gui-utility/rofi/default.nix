# FIX: For some reason not working only here...
# {
#   lib,
#   namespace,
#   config,
#   ...
# }:
# lib.${namespace}.mkIfEnabled {
#   inherit config;
#   category = "gui-utility";
#   name = "rofi";
  # extraPredicate = lib.ds-omega.isLinux;
# }
{lib, ...}:
lib.mkIf (lib.ds-omega.isLinux {}) {
  programs.rofi = {
    enable = true;

    extraConfig = {
      modes = [
        "window"
        "drun"
        "run"
        "ssh"
        "combi"
      ];
    };
  };
}
