{ ... }:

{
  programs.fzf = {
    enable = true;

    enableBashIntegration = true;
  };

  programs.bash.sessionVariables = {
    # Use as the trigger sequence instead of the default **
    FZF_COMPLETION_TRIGGER = ",,";
  };
}
