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
      /home/ds13/Projects/--personal/AiAssistance__/_skills/changelog-generator
    ];
  };
}
