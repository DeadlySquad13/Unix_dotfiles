{ pkgs, ... }:

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
