# Contributing

## Secrets Management
Use `make edit-vault` to change secrets.

### Sops Templates

#### Usage

Define secret:

```nix
{
    sops = {
        secrets = {
            codexapi_api_key = {};
        };
    };
}
```

Define template:

```nix
{
    sops = {
        templates."opencode-auth.json" = {
            content =
                /* json */ ''
                  {
                      "openai": {
                          "type": "api",
                          "key": "${config.sops.placeholder.codexapi_api_key}"
                      }
                  }
                  '';
        };
    };
}
```

Then use it via `config.sops.templates."opencode-auth.json`.path.

Sops template is not guaranteed to exist in nix store during build.

```nix
# BAD!
{
home.file.".local/share/opencode/auth.json".source =
    config.sops.templates."opencode-auth.json".path;
}
```

#### Pitfalls

It would
require you to first switch to get it into location and then another switch to
actually reference it.

So instead sops template file should be only *refernced* and used post-factum, after switching.For example, it should be used only after program is run. In this case we're managing it by creating a symlink to it's predetermined location: for symlink we only need a path, not a file.

```nix
# GOOD!
let
  inherit (lib.${namespace}) source;
in
{
    home.file.".local/share/opencode/auth.json" = source {
        inherit config;
        get-path = _p: config.sops.templates."opencode-auth.json".path;
        out-of-store = true;
    };
}
```

A whole file will be available once program is run.

[Source][@/NixOSSecretsManagement]|[Zotero][z@/NixOSSecretsManagement]

## References

[@/NixOSSecretsManagement]: <https://unmovedcentre.com/posts/secrets-management/> 'NixOS Secrets Management'
[z@/NixOSSecretsManagement]: <zotero://select/items/@/NixOSSecretsManagement> 'Select in Zotero: NixOS Secrets Management'
