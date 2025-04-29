{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "invoke";
}
{
  home.packages = with pkgs; [
    python311Packages.invoke
  ];

  home.file = {
    # If you set `out-of-store = false` (or omit it), it will make a "prod"
    # version: a whole directory with scripts will be copied into nix store and
    # reference to it will be inserted.
    ".invoke.yaml".text = /*yaml*/ ''
      tasks:
        search_root: ${(lib.${namespace}.source { inherit config; get-path = p: p.shared-scripts; out-of-store = true; }).source}
    '';
  };

  programs.bash = {
    shellAliases = {
      i = "invoke";
    };

    # For some reason _complete_alias version works only after `inv` or `invoke` are triggered
    # at least once. There's also a _complete_invoke function but don't know
    # how to get into it.
    bashrcExtra = /*bash*/ ''
      eval "$(invoke --print-completion-script bash)"
      complete -F _complete_invoke i
    '';
  };
}
