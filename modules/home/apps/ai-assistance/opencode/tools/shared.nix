{
  lib,
  config,
  namespace,
  ...
}: let
  inherit
    (lib.${namespace})
    concatParentToPathKeys
    mapValues
    sourceAttrs
    suffixKeys
    ;
  opencodeToolsPath = ".config/opencode/tool";
  toolsPath = "${config.programs.opencode.aiAssistanceDir}/_tools";
  bindingsPath = "${config.programs.opencode.aiAssistanceDir}/AiAssistance_agents__TypeScript_bindings";
  # TODO: We may eventually move from flat structure to nested. We would need
  # to process folders too.
  typeScriptSourceFiles = lib.pipe config.programs.opencode.toolWrappers [
    (toolWrappers: lib.genAttrs toolWrappers (t: "${t}.ts"))
    (suffixKeys ".ts")
  ];
  sourceFiles =
    typeScriptSourceFiles
    // {
      "package.json" = "package.json";
    };
  homeFileEntriesForSourceFiles = lib.pipe sourceFiles [
    (concatParentToPathKeys opencodeToolsPath)
    (mapValues (v: "${toolsPath}/${v}"))
    (sourceAttrs {
      inherit config;
      out-of-store = true;
    })
  ];
in {
  options.programs.opencode.toolWrappers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "List of tools that need NODE_PATH wrapper";
  };

  config = lib.mkIf (config.programs.opencode.toolWrappers != []) {
    home.file =
      homeFileEntriesForSourceFiles
      // {
        "${opencodeToolsPath}/node_modules/@aiassistance-agents/typescript-bindings".source = bindingsPath;
      };
  };
}
