{ pkgs, inputs, config, ... }:

{
  programs.broot = {
    enable = true;
    enableBashIntegration = true; # Bash should be managed by nix.
    settings = {
      verbs = [
        { invocation = "r"; execution = "ranger {directory}"; leave_broot = false; }
        { invocation = "ranger"; execution = "ranger {directory}"; leave_broot = false; }
      ];
    };
  };
}
