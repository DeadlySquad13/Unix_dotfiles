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
  # extraPredicate = lib.ds-omega.mkIfLinux;
# }
{lib, ...}:
lib.mkIf (lib.ds-omega.mkIfLinux {}) {
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
