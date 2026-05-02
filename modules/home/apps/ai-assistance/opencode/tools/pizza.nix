{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.customTools.pizza = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable custom pizza tool";
  };

  config = lib.mkIf config.programs.opencode.customTools.pizza {
    programs.opencode.toolWrappers = [ "pizza" ];
  };
}