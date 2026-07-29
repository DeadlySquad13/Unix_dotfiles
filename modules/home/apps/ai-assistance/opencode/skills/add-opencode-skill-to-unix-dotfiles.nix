{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.add-opencode-skill-to-unix-dotfiles = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable add-opencode-skill-to-unix-dotfiles opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.add-opencode-skill-to-unix-dotfiles {
    programs.opencode.skillPaths = [
      /${config.programs.opencode.skillsDir}/add-opencode-skill-to-unix-dotfiles
    ];
  };
}
