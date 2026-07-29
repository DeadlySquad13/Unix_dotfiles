{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.mcp-builder = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable mcp-builder opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.mcp-builder {
    programs.opencode.skillPaths = [
      /${config.programs.opencode.skillsDir}/mcp-builder
    ];
  };
}
