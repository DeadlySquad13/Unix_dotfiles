{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.file-organizer = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable file-organizer skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.file-organizer {
    programs.opencode.skillPaths = [
      /home/ds13/Projects/--personal/AiAssistance__/_skills/file-organizer
    ];
  };
}
