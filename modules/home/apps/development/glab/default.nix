{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "glab";
}
{
  home.packages = with pkgs; [
    glab # GitLab Cli.
  ];

  home.file.".config/glab-cli/config.yml".text = /*yaml*/ ''
    # What protocol to use when performing Git operations. Supported values: ssh, https.
    git_protocol: ssh
    # What editor glab should run when creating issues, merge requests, etc. This global config cannot be overridden by hostname.
    editor:
    # What browser glab should run when opening links. This global config cannot be overridden by hostname.
    browser:
    # Set your desired Markdown renderer style. Available options are [dark, light, notty]. To set a custom style, refer to https://github.com/charmbracelet/glamour#styles
    glamour_style: dark
    # Allow glab to automatically check for updates and notify you when there are new updates.
    check_update: true
    # Whether or not to display hyperlink escape characters when listing items like issues or merge requests. Set to TRUE to display hyperlinks in TTYs only. Force hyperlinks by setting FORCE_HYPERLINKS=1 as an environment variable.
    display_hyperlinks: false
    # Default GitLab hostname to use.
    host: gitlab.com
    # Set to true (1) to disable prompts, or false (0) to enable them.
    no_prompt: false
    # Configuration specific for GitLab instances.
    hosts:
        gitlab.com:
            # What protocol to use to access the API endpoint. Supported values: http, https.
            api_protocol: https
            # Configure host for API endpoint. Defaults to the host itself.
            api_host: gitlab.com
        gitlab.rutube.ru:
            api_protocol: https
            api_host: gitlab.rutube.ru
  '';

  /* We provision tokens via Ansible because it's not
  possible with nix-sops alone to include it into file securely.
  https://discourse.nixos.org/t/how-to-set-environment-variables-with-sops-nix/38980
  
    We use env only for default host with personal token.
  https://discourse.nixos.org/t/how-to-set-environment-variables-with-sops-nix/38980/2

    But shellInit is not available for home-manager so it's only left to use bashrcExtra.
  */
  programs.bash = {
    bashrcExtra = /*bash*/ ''
      export GITLAB_TOKEN="$(cat ${config.sops.secrets.glab_DeadlySquad13_token.path})"
    '';
  };
}
