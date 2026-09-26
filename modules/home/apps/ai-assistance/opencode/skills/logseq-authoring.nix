{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.logseq-authoring = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable logseq-authoring opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.logseq-authoring {
    programs.opencode.skillPaths = [
      /${config.programs.opencode.skillsDir}/logseq-authoring
    ];
  };
}
