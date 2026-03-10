{
  pkgs,
  inputs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "cli-utility";
  name = "batch";
  # INFO: This package triggers buildinng of llvm 22.1.0-rc3 on darwin and
  # errors on 1 test:
  # Support/./SupportTests/ProgramEnvTest/TestExecuteEmptyEnvironment
  # TODO: Check after next update of flake inputs.
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  # home.packages = with inputs; [
  home.packages = with pkgs; [
    ds-omega.batch
  ];
}
