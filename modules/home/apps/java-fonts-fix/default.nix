{...}:
# TODO: Move it to a layer.
{
  programs.bash = {
    sessionVariables = {
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=gasp";
    };
  };
}
