{
  lib,
  config,
  ...
}:
lib.ds-omega.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops-opencode";
}
{
  # Created by the NixOS sops-opencode module. This Home Manager profile only
  # passes its runtime path to Docker Compose and does not evaluate SOPS.
  # FIX: Infinite recursion
  ds-omega.ai-assistance.opencode.mcp.logseqEnvironmentFile = "/run/secrets/rendered/logseq-mcp.env";
}
