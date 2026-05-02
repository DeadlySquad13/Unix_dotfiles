{
  lib,
  config,
  namespace,
  ...
}:
let
  inherit (lib.${namespace}) prefixKeys prefixValues sourceAttrs;
  opencodeToolsPath = ".config/opencode/tool";
  toolsPath = "/home/ds13/Projects/--personal/AiAssistance__/_tools";
  bindingsPath = /home/ds13/Projects/--personal/AiAssistance__/AiAssistance_agents__TypeScript_bindings;
in
{
  options.programs.opencode.toolWrappers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "List of tools that need NODE_PATH wrapper";
  };

  config = lib.mkIf (config.programs.opencode.toolWrappers != [ ]) {
    home.file = lib.pipe null [
      (_: lib.genAttrs config.programs.opencode.toolWrappers (t: "${t}.ts")
        // { "package.json" = "package.json"; })
      (prefixKeys opencodeToolsPath)
      (prefixValues (v: "${toolsPath}/${v}"))
      (sourceAttrs { inherit config; out-of-store = true; })
    ]
    // {
      "${opencodeToolsPath}/node_modules/@aiassistance-agents/typescript-bindings".source = bindingsPath;
    };
  };
}
