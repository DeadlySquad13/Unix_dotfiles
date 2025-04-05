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
    ".invoke.yaml".text = ''
      tasks:
        search_root: ${lib.${namespace}.get-path { inherit config; cb = p: p.shared-scripts; }}
    '';
  };

  programs.bash = {
    shellAliases = {
      i = "invoke";
    };

    # For some reason _complete_alias version works only after `inv` or `invoke` are triggered
    # at least once. There's also a _complete_invoke function but don't know
    # how to get into it.
    bashrcExtra = ''
      eval "$(invoke --print-completion-script bash)"
      complete -F _complete_invoke i
    '';
  };
}
