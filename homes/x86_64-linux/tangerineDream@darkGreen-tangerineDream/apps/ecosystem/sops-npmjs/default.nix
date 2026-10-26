{
  lib,
  config,
  namespace,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops-npmjs";
}
{
  # The darkGreen system renders the npm auth token with system-level SOPS at
  # `/run/secrets/rendered/npmrc`. This Home Manager profile does not evaluate
  # Home Manager SOPS, so it consumes the system-rendered runtime path
  # explicitly. Keep this literal in sync with the system module's
  # `runtimePath` option and the system-to-home mapping in ADR 0008.
  ${namespace}.ecosystem.sops-npmjs.systemRuntimePath = "/run/secrets/rendered/npmrc";
}
