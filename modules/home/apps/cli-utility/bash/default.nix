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

      # Things that I rarely use and don't want to store permanently as a package.
      speedtest = "nix-shell -p speedtest-cli --run speedtest";
      speedtestKarimka = "proxychains4 nix-shell -p speedtest-cli --run speedtest";
    };

    bashrcExtra = /*bash*/ ''
      # Personal profile.
      [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc
    '';
  };

  home.file = {
    ".bash" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Bash_config";
      out-of-store = true;
    };
    # ".bash".source = config.lib.${na"${config.lib.${namespace}.paths.shared-configs}/Bash_config"};
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
