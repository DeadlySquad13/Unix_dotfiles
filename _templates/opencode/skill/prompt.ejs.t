---
to: modules/home/apps/ai-assistance/opencode/skills/<%= name %>.nix
---
{
  lib,
  config,
  ...
}: {
  imports = [
    ./shared.nix
  ];

  options.programs.opencode.enabledSkills.<%= name %> = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable <%= name %> opencode skill";
  };

  config = lib.mkIf config.programs.opencode.enabledSkills.<%= name %> {
    programs.opencode.skillPaths = [
      <% if (path) { -%>
      <%= path %>/<%= name %>
      <% } else { -%>
      /${config.programs.opencode.skillsDir}/<%= name %>
      <% } -%>
    ];
  };
}
