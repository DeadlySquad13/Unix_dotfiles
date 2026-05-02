{
  lib,
  config,
  namespace,
  ...
}:
let
  inherit (lib.${namespace}) source;
  opencodeToolsPath = ".config/opencode/tool";
  toolsPath = "/home/ds13/Projects/--personal/AiAssistance__/_tools";
  bindingsPath = /home/ds13/Projects/--personal/AiAssistance__/AiAssistance_agents__TypeScript_bindings;
  # opencodeToolWrapper = toolName: ''
  #   #!/bin/sh
  #   export NODE_PATH="${toolsPath}/node_modules:$NODE_PATH"
  #   exec "${toolsPath}/${toolName}.ts" "$@"
  # '';
  # opencodeToolWrapperPath = toolName: {
  #   source = builtins.toFile "opencode-${toolName}" (opencodeToolWrapper toolName);
  #   executable = true;
  # };
in
{
  options.programs.opencode.toolWrappers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "List of tools that need NODE_PATH wrapper";
  };

  config = lib.mkIf (config.programs.opencode.toolWrappers != [ ]) {
    home.file =
      builtins.mapAttrs
        (
          name: value:
          source {
            inherit config;
            get-path = _p: value;
            out-of-store = true;
          }
        )
        (
          lib.attrsets.concatMapAttrs
            (name: relativePath: {
              "${opencodeToolsPath}/${name}.ts" = "${toolsPath}/${relativePath}";
            })
            (
              (lib.genAttrs config.programs.opencode.toolWrappers (toolName: toolName + ".ts"))
              // {
                "package.json" = "package.json";
              }
            )
        )
      // {
        "${opencodeToolsPath}/node_modules/@aiassistance-agents/typescript-bindings".source = bindingsPath;
      };
  };
}
