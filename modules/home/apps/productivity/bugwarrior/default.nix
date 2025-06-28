{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "bugwarrior";
}
{
  home.packages = with pkgs; [
    # Doesn't work with Python3.12 out of the box.
    # https://github.com/GothenburgBitFactory/bugwarrior/issues/1050
    # Last version 1.8.0 was released in 2020.
    # https://github.com/GothenburgBitFactory/bugwarrior/issues/1030
    # python311Packages.bugwarrior
    python3Packages.bugwarrior-develop
  ];

  home.file = {
    ".config/bugwarrior/bugwarrior.toml".text =
      /*
      toml
      */
      ''
        [general]
        targets = ["my_logseq_graph"]

        # When true will include a link to the ticket as an annotation.
        annotation_links = true

        [my_logseq_graph]
        service = "logseq"
        token = "mybugwarrioraccesstoken"
      '';
  };
}
