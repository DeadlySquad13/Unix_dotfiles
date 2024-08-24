{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "writing";
  name = "pandoc";
}
{
  programs.pandoc = {
    enable = true;

    # Good for converting notebooks via html (webkit) to pdf route.

    defaults = ''
      {
        metadata = {
          author = "John Doe";
        };
        pdf-engine = "wkhtmltopdf";
        citeproc = true;
      }
    '';
  };

  # Considered insecure.
  # home.packages = with pkgs; [
  #   wkhtmltopdf
  # ];
}
