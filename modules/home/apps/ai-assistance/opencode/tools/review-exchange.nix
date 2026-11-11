{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.customTools."review-exchange" = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable custom review-exchange tool";
  };

  config = lib.mkIf config.programs.opencode.customTools."review-exchange" {
    programs.opencode.toolWrappers = [ "review-exchange" ];
  };
}
