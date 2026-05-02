{
  lib,
  config,
  ...
}:
let
  inherit (lib) baseNameOf;
  inherit (config.programs.opencode) skillPaths;
in
{
  options.programs.opencode.skillPaths = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "List of skill paths to enable";
  };

  config = lib.mkIf (skillPaths != [ ]) {
    # Will transform `[paths] -> { [nameOfFolder] = path; }`.
    programs.opencode.skills = lib.genAttrs' skillPaths (sp: lib.nameValuePair (baseNameOf sp) sp);
  };
}
