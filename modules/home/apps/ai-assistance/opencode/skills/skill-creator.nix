{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.skill-creator = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable skill-creator opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.skill-creator {
    programs.opencode.skillPaths = [
      /home/ds13/Projects/--personal/AiAssistance__/_skills/skill-creator
    ];
  };
}
