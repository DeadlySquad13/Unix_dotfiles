{
  lib,
  config,
  ...
}:
let
  inherit (lib) baseNameOf;
  inherit (config.programs.opencode) skillPaths;
  existingSkillPaths = builtins.filter builtins.pathExists skillPaths;
in
{
  options.programs.opencode.skillPaths = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "List of skill paths to enable";
  };

  # This wiring is old and still has several call sites/connections. The
  # external AiAssistance__ tree is not guaranteed to exist on every host, so a
  # missing skill path must be skipped rather than failing evaluation. Skipping
  # is intentional and does not affect hosts where the paths exist; existing
  # paths are passed through unchanged.
  config = lib.mkIf (existingSkillPaths != [ ]) {
    # Will transform `[paths] -> { [nameOfFolder] = path; }`.
    programs.opencode.skills = lib.genAttrs' existingSkillPaths (sp: lib.nameValuePair (baseNameOf sp) sp);
  };
}
