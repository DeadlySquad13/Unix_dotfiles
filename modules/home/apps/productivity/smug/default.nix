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
  name = "smug";
}
(let
  # On 0.3.5 and 0.3.6 --file attribute doesn't work.
  # https://github.com/ivaaaan/smug/issues/137
  smug-0_3_3 = pkgs.smug.overrideAttrs (oldAttrs: rec {
    pname = "smug";
    version = "0.3.3";

    src = pkgs.fetchFromGitHub {
      owner = "ivaaaan";
      repo = pname;
      rev = "v${version}";
      sha256 = "sha256-dQp9Ov8Si9DfziVtX3dXsJg+BNKYOoL9/WwdalQ5TVw=";
    };
  });
in {
  home.packages = [
    smug-0_3_3
  ];

  home.file = {
    # Solution for normies like me who are still not 100% into immutable.
    # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    ".config/smug" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/smug/.config/smug";
      out-of-store = true;
    };
  };
})
