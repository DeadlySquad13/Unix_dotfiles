{namespace, ...}: {
  # Use gl-* version of the package if deployment environment supports it,
  # otherwise fallback to regular variant of the package.
  # To control it, pass in config with `config.lib.${namespace}.deploymentOptions` set.
  #
  # Example usage in a module:
  # home.packages = [
  #   (lib.${namespace}.packageGLify "ferdium")
  # ];
  packageGLify = {
    config,
    pkgs,
  }: packageName:
    if config.lib.${namespace}.deploymentOptions.isNixGlNotWorking
    then pkgs."${packageName}"
    else pkgs.${namespace}."gl-${packageName}";
}
