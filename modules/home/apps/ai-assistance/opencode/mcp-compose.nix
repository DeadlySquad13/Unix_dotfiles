{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.opencode.mcpContainers;
  # If `enable` is not defined - still process.
  shouldBeContainerized = _: serverConfig: (serverConfig.enable or true) && serverConfig ? image;
in {
  config = lib.mkIf (config.programs.opencode.enable && cfg.enable && pkgs.stdenv.isLinux) {
    home.file.".config/mcp-containers/compose.yaml".source = lib.ds-omega.generateMcpCompose {
      servers = lib.filterAttrs shouldBeContainerized cfg.servers;
      inherit pkgs;
    };

    systemd.user.services.opencode-mcp = {
      Unit = {
        Description = "OpenCode MCP container stack";
        After = ["docker.socket"];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "%h/.config/mcp-containers";
        Environment = ["DOCKER_HOST=${cfg.dockerHost}"];
        ExecStart = "${pkgs.docker}/bin/docker compose --project-name opencode-mcp --file compose.yaml up --detach --remove-orphans";
        ExecStop = "${pkgs.docker}/bin/docker compose --project-name opencode-mcp --file compose.yaml stop";
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
