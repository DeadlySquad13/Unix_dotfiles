{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.logseq-db-queries = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable logseq-db-queries skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.logseq-db-queries {
    programs.opencode.skillPaths = [
      /shared/archive-resources-/Resources/KnowledgeBase__Data/_skills/logseq-db-queries
    ];
  };
}
