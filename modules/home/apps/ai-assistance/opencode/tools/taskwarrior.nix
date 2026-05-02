{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.customTools.taskwarrior = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable custom taskwarrior tool";
  };

  config = lib.mkIf config.programs.opencode.customTools.taskwarrior {
    programs.opencode.toolWrappers = [ "taskwarrior" ];
  };
}
