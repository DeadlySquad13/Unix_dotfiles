{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "broot";
}
{
  programs.broot = {
    enable = true;
    enableBashIntegration = true; # Bash should be managed by nix.
    settings = {
      verbs = [
        { invocation = "r"; execution = "ranger {directory}"; leave_broot = false; }
        { invocation = "ranger"; execution = "ranger {directory}"; leave_broot = false; }

        # TODO: Move vi-dev aand vi-stage to bash utils and set `leave_broot
        # = false` and remove `from_shell`.
        #
        # `from_shell = true` and `leave_broot = false` are not compatible.
        # I wish I had `leave_broot = false```, though. But broot doesn't interpret
        # aliases (it seems it doesn't source bashrc) and doesn't work with `NVIM_APPNAME=nvim-dev nvim`
        # (it says "No such file or directory" - I assume it interprets
        # variable set incorrectly).
        { invocation = "es"; execution = "nvim-stage {file}"; from_shell = true; leave_broot = true; }
        { invocation = "edit-stage"; execution = "nvim-stage {file}"; from_shell = true; leave_broot = true; }

        { invocation = "edit-dev"; execution = "nvim-dev {file}"; from_shell = true; leave_broot = true; }
        { invocation = "ed"; execution = "nvim-dev {file}"; from_shell = true; leave_broot = true; }
      ];
    };
  };
}
