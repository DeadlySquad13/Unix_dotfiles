{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.logseq-authoring-suite = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable logseq-authoring-suite opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.logseq-authoring-suite {
    programs.opencode.skillPaths = [
      /${config.programs.opencode.skillsDir}/logseq-authoring-suite
    ];
  };
}
