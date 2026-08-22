{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  mcpoBaseUrl = "http://localhost:8001";
  mcpoUrl = serverName: mcpoBaseUrl + "/" + serverName + "/docs";
in {
  config = mkIf config.programs.opencode.enable {
    programs.opencode.enableMcpIntegration = true;

    programs.mcp = {
      enable = true;

      servers = {
        time = {
          url = mcpoUrl "time";
        };
        fetch = {
          url = mcpoUrl "fetch";
        };
        logseq = {
          url = mcpoUrl "logseq";
        };
        ddg-search = {
          url = mcpoUrl "ddg-search";
        };
        nixos = {
          url = mcpoUrl "nixos";
        };
        nixos-docker = {
          command = "docker";
          args = [
            "run"
            "--rm"
            "-i"
            "ghcr.io/utensils/mcp-nixos"
          ];
        };
      };
    };
  };
}
