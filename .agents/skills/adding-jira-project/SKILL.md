---
name: adding-jira-project
description: Use this skill when adding a Jira space/project or Atlassian Cloud site to the `development.jira-cli` Home Manager module. It gathers the org/site/space, Cloud ID, token scope, key, and proxychains requirement from the user, edits the host's home config, validates that SOPS keys exist, and verifies the generated jira profile.
---

# Add a Jira space to `development.jira-cli`

## Scope

Use this skill when:

- a new Jira space/project must be searchable with `jira` / `jira.py`;
- a space was added but 404s (usually the wrong site);
- a new Atlassian Cloud site or organization needs an entry.

Do not use this skill to create API tokens. Ask the user to create or rotate the token at
`https://id.atlassian.com/manage-profile/security/api-tokens` with the Jira scopes and add it to
the SOPS vault first.

## Model: two shapes

1. **Cloud (preferred), mirrors Jira:** `orgs.<org>.sites.<site>.spaces.<SPACE>`
   - `org` owns the shared connection fields: `loginSecret`, `tokenSecret`, `installation`,
     `authType`, `useProxychains`;
   - `site` owns `server`/`serverSecret` and `cloudId`;
   - `space` owns the Jira key and metadata (`spaceType`, `epicName`, `epicLink`, `board`,
     `extraConfig`).
   - Profile id = `<org>-<site>-<SPACE>`; executable = `jira-<org>-<site>-<SPACE>`.
   - `site.defaultSpace` adds `jira-<org>-<site>` (shortcut for that site's default space).

2. **Legacy Server/Data Center (older jira-cli):** `spaces.<space>.projects.<PROJECT>`
   - Profile id = `<space>-<PROJECT>`; executable = `jira-<space>-<PROJECT>`.
   - `space.defaultProject` adds `jira-<space>`.
   - Keep this path for existing Server/DC hosts; do not migrate them just for terminology.

The module still renders jira-cli's `project:` block. For Cloud spaces, `spaceType` maps to
`project.type`.

### Inheritance

Fields merge down the tree: **org → site → space** (legacy: space → project). A deeper node
overrides only what it sets; unset fields inherit. This works at every level:

```nix
orgs.ds13 = {
  loginSecret = "jira_personal_login";
  sites.antiskuf = {
    loginSecret = "jira_antiskuf_personal_login"; # only this site differs
  };
};
```

Put `loginSecret`, `tokenSecret`, `installation`, `authType`, `useProxychains` on the org when
all its sites share them. Put `server`/`cloudId` on each site. Override at a space only for a
space-specific token or setting.

Read `modules/home/apps/development/jira-cli/default.nix` for the authoritative options.

## Ask the user first

Never guess the site, key, or secret names. Ask these in one batch (use the `question` tool for
choices, prose for free-form values) and wait for the answers before editing:

1. **Home**: which host config should get it? Find candidates:
   ```bash
   grep -rn "development.jira-cli" homes
   ```
   Expect `homes/<system>/<user>@<host>/default.nix`.
2. **Shape**: Cloud `orgs` or legacy `spaces`?
   - existing Cloud org/site: which `orgs.<org>.sites.<site>`?
   - new Cloud site: the site URL (`https://<name>.atlassian.net`);
   - new Cloud org: the account and shared login/token;
   - legacy Server/DC: which `spaces.<space>`?
3. **Account**: which login secret? (`jira_personal_login`, `jira_work_login`, ...)
4. **Token**: which token secret? Is it **scoped** or **classic**?
   - scoped → need `cloudId`;
   - classic → site URL only.
5. **Key**: the real Jira space/project key (e.g. `ASDRE`), not the JPD display name/slug. Ask
   for one item URL: `https://<site>.atlassian.net/browse/<KEY>-1`.
6. **Display name**: the human/JPD space name (e.g.
   `AntiSkuf_discovery--roadmap-exploration`) for comments only.
7. **Type**: JPD/team-managed (`next-gen`) or classic?
8. **Proxychains**: is this site reachable only through the user's proxy? Set it once on the
   org if all its sites are proxied; work stays direct.
9. **Defaults**: should this become `site.defaultSpace` (`jira-<org>-<site>`),
   `space.defaultProject` (legacy `jira-<space>`), or `development.jira-cli.default` (bare
   `jira`)? Usually **no**; adding a space must not silently move the default.

If the user says “same org” but names a different site, add a **new `sites.<site>`** with its
own `cloudId`. Do not put its spaces under another site; they will 404.

## Procedure

1. Locate the host’s `development.jira-cli` block.
2. Ask the questions above and record the answers.
3. For a new Cloud site, read the public Cloud ID:
   ```bash
   curl -sS https://<site>.atlassian.net/_edge/tenant_info \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["cloudId"])'
   ```
4. Confirm every referenced secret key exists (names only; never decrypt or print values):
   ```bash
   grep -nE '^<server-secret>:|^<login-secret>:|^<token-secret>:' secrets/secrets.yaml
   ```
   `sops-install-secrets` fails the build with `the key '<name>' cannot be found` if one is
   missing. If a new site needs a new token, the user must add it to SOPS before the switch.
5. Edit the home config.
6. Validate and apply.
7. Verify the generated profile.

## Templates

### Add a space to an existing Cloud site

```nix
orgs.<org>.sites.<site>.spaces.<SPACE> = {
  # JPD/team-managed: next-gen; classic otherwise.
  spaceType = "next-gen";
  # Optional: extraConfig = ''...'';  # jira init metadata (issue types, fields)
};
```

Do not touch `defaultSpace` / `default` unless the user asked.

### Add a Cloud site to an existing org

```nix
orgs.<org>.sites.<site> = {
  # Scoped tokens use the gateway; the module renders:
  #   server: https://api.atlassian.com/ex/jira/<cloudId>
  #   browse_server: <site>
  # A classic/unscoped token uses the site URL and no cloudId.
  server = "https://<site>.atlassian.net";      # or serverSecret
  cloudId = "<cloud-id>";
  defaultSpace = "<SPACE>";                     # optional: jira-<org>-<site>
  spaces.<SPACE> = {
    spaceType = "next-gen";
  };
};
```

`loginSecret`, `tokenSecret`, `installation`, `authType` and `useProxychains` are inherited
from the org; override only the fields that differ for this site.

### Add a new Cloud org (new account)

```nix
orgs.<org> = {
  loginSecret = "<login-secret>";
  installation = "Cloud";
  tokenSecret = "<token-secret>";
  useProxychains = true;                        # only if these sites are proxied
  sites.<site> = {
    server = "https://<site>.atlassian.net";    # or serverSecret
    cloudId = "<cloud-id>";
    defaultSpace = "<SPACE>";
    spaces.<SPACE>.spaceType = "next-gen";
  };
};
```

### Legacy Server/Data Center (do not use for new Cloud configs)

```nix
spaces.<space> = {
  serverSecret = "<server-secret>";
  loginSecret = "<login-secret>";
  tokenSecret = "<token-secret>";
  installation = "Local";
  authType = "bearer";                          # Server/DC PAT
  defaultProject = "<PROJECT>";                 # optional: jira-<space>
  projects.<PROJECT> = {
    projectType = "classic";
  };
};
```

Do not set `cloudId` for Server/DC.

### Real examples in this repo

`homes/x86_64-linux/ds13@salt/default.nix` (Cloud):

- `orgs.ds13` → shared `jira_personal_login`, `jira_personal_ds13_org_token`,
  `useProxychains = true`; JPD-only token `jira_personal_ds13_org_product_discovery_token`
- `orgs.ds13.sites.antiskuf` → `serverSecret jira_personal_antiskuf_site_server`,
  `cloudId 0a71…`, space `ASDRE`
- `orgs.ds13.sites.finding-work` → `serverSecret jira_personal_finding_job_site_server`,
  `cloudId b513…`, space `FJDRE`

Profiles are `ds13-antiskuf-ASDRE` and `ds13-finding-work-FJDRE`; shortcuts are
`jira-ds13-antiskuf` and `jira-ds13-finding-work`. Both are proxied.

`homes/aarch64-darwin/apakalo@creamsoda/default.nix` (legacy Server/DC):

- `spaces.rutube.projects.AHUB` → profile `rutube-AHUB`, shortcut `jira-rutube`, not proxied.

## Validate and apply

```bash
nix-instantiate --parse homes/<system>/<user>@<host>/default.nix
# Use the host's normal switch/build; e.g.
home-manager switch --flake .#<user>@<host>
```

The module exports:

- `JIRA_PROFILES` (e.g. `ds13-antiskuf-ASDRE ds13-finding-work-FJDRE ds13-antiskuf ds13-finding-work`)
- `JIRA_PROFILE_EXECUTABLES`
- `JIRA_DEFAULT_PROFILE`
- `JIRA_CONFIG_FILE` / `JIRA_AUTH_TYPE` for the default

## Verify

Cloud:

```bash
jira.py profiles
jira-ds13-antiskuf-ASDRE issue list --project ASDRE --plain
jira-ds13-antiskuf issue list --project ASDRE --plain   # defaultSpace
jira-ds13-antiskuf-ASDRE open ASDRE-1                    # must use the site URL
```

Legacy:

```bash
jira-rutube-AHUB issue list --project AHUB --plain
jira-rutube issue list --project AHUB --plain
```

Bypass Nix temporarily:

```bash
python3 scripts/jira-probe.py --server https://<site>.atlassian.net \
  --project <KEY> --debug-auth

python3 scripts/jira-cli-try.py --site https://<site>.atlassian.net \
  --token-secret <token-secret> --project <KEY> \
  -- issue list --project <KEY> --plain
```

Add `--proxychains` to `jira-cli-try.py` if the site is behind the proxy. The probe
auto-switches to the gateway when a scoped-token 401 appears on the site URL. The harness
defaults to `jira_personal_ds13_org_token`; pass `--token-secret` for another account.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `sops-install-secrets ... key '<name>' cannot be found` | Secret name not in `secrets/secrets.yaml` | Add the key or correct the name. |
| `jira-<...>: command not found` | Switch/build did not run or failed | Re-run the switch; check the first error. |
| `unknown profile` | Used `<KEY>` instead of `<org>-<site>-<space>` | Use the profile id or the `jira-<org>-<site>` shortcut. |
| Profile id collision | Two sites in one org share a space attr name | Rename one space attr or split the site into its own org. |
| 401 | Wrong email/token; scoped token used on the site URL; token expired/revoked | Set `cloudId`; verify the account email; rotate the token. |
| 403 | Missing `read:jira-work` / `read:jira-user`; no Browse permission | Add scopes or grant access. |
| 404 | Wrong key, wrong site, or no permission | Get a real `/browse/<KEY>-<n>` URL; confirm the site host. |
| `open` goes to `api.atlassian.com` | Missing `browse_server` | Set `cloudId`; the module renders `browse_server` from `server` / `serverSecret`. |
| Works for one space, 404 for another on “the same org” | They are on different sites | Add a separate `sites.<site>` with its own `cloudId`. |

## Pitfalls

- **Do not derive the key from the JPD display name.** `FindingJob_discovery--roadmap-exploring`
  is a display name; the key `FJDRE` was confirmed only by an item URL.
- **Org ≠ site.** `ds13` can contain `antiskuf` and `finding-work`; each site needs its own
  `cloudId` and `sites.<site>` entry.
- **Scoped tokens must use the gateway.** `cloudId` is not optional for scoped tokens; basic
  auth against the site URL returns 401.
- **`browse_server` keeps links human.** `server` is the API endpoint; `open` uses
  `browse_server`.
- **Fields merge down the tree.** Put shared `loginSecret`/`tokenSecret`/`installation`/
  `authType`/`useProxychains` on the org; a site or space overrides only what it sets.
  Repeating inherited values is not needed.
- **Proxychains is per org/site/space.** Set `useProxychains` only for proxied personal sites;
  work stays direct. Bare `jira` is not proxied — use the profile wrapper or `jira.py`.
- **Do not change defaults implicitly.** Adding a space should not change
  `default` / `defaultSpace` / `defaultProject` unless the user asked.
- **Profile ids must match `[A-Za-z0-9_-]+` and be unique.** Cloud ids are
  `<org>-<site>-<space>`; legacy ids are `<space>-<project>`.
- **Keep Server/DC on the legacy path.** The creamsoda work host intentionally uses
  `spaces.<space>.projects.<project>` with an older jira-cli; do not migrate it to `orgs`.
- **Secrets stay in SOPS.** Never put token values (or private server URLs) in Nix, logs,
  commits, or examples. `grep` key names only.
- **Token scopes:** `read:jira-work` for search/view, `read:jira-user` for `/myself`,
  `write:jira-work` for create/edit/comment. Scoped tokens expire; rotation is a SOPS value
  update.

## Done when

- `nix-instantiate --parse` passes.
- The switch succeeds and `jira-<org>-<site>-<space>` is on `PATH`.
- `JIRA_PROFILES` includes the new id and `jira.py profiles` lists it.
- `jira-<org>-<site>-<space> issue list --project <KEY> --plain` returns rows.
- `jira-<org>-<site>-<space> open <KEY>-1` opens the site URL.
- No secret value or private URL was written to Nix, logs, or commits.
