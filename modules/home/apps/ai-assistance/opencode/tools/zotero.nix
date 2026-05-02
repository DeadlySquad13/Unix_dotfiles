{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.customTools.zotero = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable custom zotero tool";
  };

  config = lib.mkIf config.programs.opencode.customTools.zotero {
    programs.opencode.toolWrappers = [ "zotero" ];
  };
}