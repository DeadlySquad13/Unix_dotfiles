{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "java-fonts-fix";
  extraPredicate = lib.${namespace}.mkIfLinux;
}
# TODO: Move it to a layer.
{
  programs.bash = {
    sessionVariables = {
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=gasp";
    };
  };
}
