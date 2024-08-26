{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "bash";
}
{
  programs.bash = {
    enable = true;
    # Completion script was causing errors on shell startup because of `[ "$vars" ]`.
    enableCompletion = true;

    shellAliases = {
      # https://joshtronic.com/2021/05/23/unlock-user-after-too-many-failed-sudo-attempts/
      resetFailLock = "faillock --user $USER --reset";
    };

    # TODO: Move pixi to a separate layer.
    bashrcExtra = ''
      # Personal profile.
      [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc

      # Pixi completion.
      eval "$(pixi completion --shell bash)"
    '';
  };

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;
    # ".bash".source =
    #   pkgs.fetchFromGitHub {
    #     owner = "DeadlySquad13";
    #     repo = "Bash_config";
    #     rev = "1670b3214feaf69708add2f0978cb94472fb0bab";
    #     hash = "sha256-zmkhIdSOvq+RR2Xri9lB8cZRPDBhH6VmvjPkRdVusFw=";
    #   };
  };

  # TODO: Move all these to layer.
  # imports = [
  #   ../complete-alias/default.nix
  # ];
}
