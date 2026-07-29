{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.changelog-generator = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable changelog-generator opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.changelog-generator {
    programs.opencode.skillPaths = [
      /${config.programs.opencode.skillsDir}/changelog-generator
    ];
  };
}
