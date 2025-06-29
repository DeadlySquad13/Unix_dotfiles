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
  programs.taskwarrior = {
    extraConfig =
      /*
      ini
      */
      ''
        # Bugwarrior UDAs
        uda.logseqid.type=string
        uda.logseqid.label=Logseq ID
        uda.logsequuid.type=string
        uda.logsequuid.label=Logseq UUID
        uda.logseqstate.type=string
        uda.logseqstate.label=Logseq State
        uda.logseqtitle.type=string
        uda.logseqtitle.label=Logseq Title
        uda.logseqdone.type=date
        uda.logseqdone.label=Logseq Done
        uda.logsequri.type=string
        uda.logsequri.label=Logseq URI
        # END Bugwarrior UDAs
      '';
  };

  home.file = {
    ".config/bugwarrior/bugwarrior.toml".text =
      /*
      toml
      */
      ''
        [general]
        taskrc = "~/.config/task/taskrc"
        targets = ["my_logseq_graph"]
        static_fields = ["project"]

        # When true will include a link to the ticket as an annotation.
        annotation_links = true

        [my_logseq_graph]
        service = "logseq"
        token = "token"
        host = "172.18.208.1"
        project_template = ""
      '';
  };
}
