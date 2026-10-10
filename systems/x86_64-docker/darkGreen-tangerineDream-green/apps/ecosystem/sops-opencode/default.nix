{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (config.lib.${namespace}.common) spiceNamespace systemBaseName;

  # Persistent opencode data directory shared with the host. The
  # runtime-home-bridge symlinks it to ~/.local/share/opencode, so auth must be
  # exposed here (not as a home-manager file) to keep that path a symlink.
  opencodeAuthPath = "/usr/local/${spiceNamespace}-/${systemBaseName}/_share/opencode/auth.json";
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ecosystem";
    name = "sops-opencode";
  }
  {
    sops.age.keyFile = "/usr/local/${spiceNamespace}-/${systemBaseName}/_configs/sops/age/keys.txt";
    # SOPS still renders the template in its secret store; `path` only selects
    # where the rendered file is exposed as a symlink.
    sops.templates."opencode-auth.json".path = opencodeAuthPath;
    ds-omega.ai-assistance.opencode = {
      # Tells modules/nixos/ai-assistance/opencode to let this external layer own
      # auth instead of materialising ~/.local/share/opencode via home.file.
      authPath = opencodeAuthPath;
      # The username of the main user that runs opencode.
      # Used for permissions.
      username = systemBaseName;
    };
  }
