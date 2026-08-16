# Sops
Layered structure:
1. System
    1. Define base Sops system settings: ../../modules/nixos/ecosystem/sops/default.nix
    2. Define Opencode specific Sops settings: ../../modules/nixos/ecosystem/sops-opencode/default.nix
        - define secret,
        - define template.
    3. Tie into opencode config: ../../modules/nixos/ai-assistance/opencode/default.nix
        - symlink home-manager file to template.
2. Per-system overrides
    1. Override keyFile according to our docker volumes, set
       `ds-omega.ai-assistance.opencode` settings for system layer module:
    ../../systems/x86_64-docker/darkGreen-tangerineDream-green/apps/ecosystem/sops-opencode/default.nix
3. HomeManager
    1. Define sops settings: ../../modules/home/apps/ecosystem/sops/default.nix
    1. Define opencode settings:
       ../../modules/home/apps/ai-assistance/opencode/default.nix
       - takes into account that API keys can be defined by sops on any of the
         levels. The narrower level, the more priority it has.


