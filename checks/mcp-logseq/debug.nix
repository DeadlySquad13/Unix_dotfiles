# mcp-logseq debug dump.
#
# Prints, per agent, the ACTUAL derived ACL contract sent to each mcp-logseq
# server, by evaluating the REAL mcp.nix module with the REAL global namespace
# values imported from
#   modules/home/apps/ai-assistance/opencode/logseq-profiles.nix
# (the module only needs `lib.mkDefault` unwrapped and nothing else).
# Per-host glue (logseqEnvironmentFile / logseqHost) is provided below as it
# lives in the host's sops-opencode module, not in logseq-profiles.nix.
#
# Emits a JSON object (server -> { hostPort, env, stdioCommand, grant }) so the
# Makefile target can pretty-print it with `python3 -m json.tool`.
#
#   nix-instantiate --eval \
#     checks/mcp-logseq/debug.nix
let
  namespace = "ds-omega";

  # Path to the repo root (2 levels up from this checks/mcp-logseq/ dir), as a
  # path literal (no @), then joined with module paths.
  repoRoot = ../..;

  pkgs = import <nixpkgs> {};

  # Per-host glue (matches homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode).
  logseqEnvironmentFile = "/run/secrets/logseq-mcp.env";
  logseqHost = "salt";

  # Unwrap lib.mkDefault and mock the namespace mkIfEnabled so the global
  # profile module evaluates unconditionally. `inputs.mcp-logseq` is the Nix
  # store source path the real flake provides (here a repo-relative stand-in).
  mcpLogseqSrc = repoRoot + "/.";

  profileLib = pkgs.lib // {
    mkDefault = x: x;
    ${namespace} = pkgs.lib // {
      mkIfEnabled = _: module: module;
    };
  };

  profileModule = import
    (repoRoot + "/modules/home/apps/ai-assistance/opencode/logseq-profiles.nix")
    {
      lib = profileLib;
      inherit namespace;
      inputs = {mcp-logseq = mcpLogseqSrc;};
    };

  profileVals = profileModule.${namespace}.ai-assistance.opencode.mcp;

  # Option defaults are NOT auto-applied outside the module system: merge each
  # profile's defaults ourselves (writeSets/readSets/readAllAgentOwns/
  # readAllNamespaces).
  withDefaults = _: prof:
    prof
    // {
      writeSets = prof.writeSets or [];
      readSets = prof.readSets or [];
      readAllAgentOwns = prof.readAllAgentOwns or false;
      readAllNamespaces = prof.readAllNamespaces or false;
    };

  profiles = builtins.mapAttrs withDefaults profileVals.logseqAgentProfiles;

  # Overlay mkIf so the plain `settings` config body (agent/tools/mcp) is
  # readable (both enable conditions are true under `providedConfig`).
  lib = pkgs.lib // {
    mkIf = _: x: x;
  };

  providedConfig = {
    programs.opencode.enable = true;
    programs.opencode.mcpContainers = {
      enable = true;
      accessMode = "host";
    };
    "ds-omega".ai-assistance.opencode.mcp = {
      inherit logseqEnvironmentFile logseqHost;
      logseqSrc = mcpLogseqSrc;
      logseqSharedNamespaces = profileVals.logseqSharedNamespaces;
      logseqNamespaceSets = profileVals.logseqNamespaceSets;
      logseqAgentProfiles = profiles;
      logseqSummarizerProfiles = builtins.mapAttrs withDefaults profileVals.logseqSummarizerProfiles;
    };
  };

  m = (import (repoRoot + "/modules/home/apps/ai-assistance/opencode/mcp.nix")) {
    inherit lib;
    config = providedConfig;
  };

  servers = m.options.programs.opencode.mcpContainers.servers.default;
  settings = m.config.programs.opencode.settings;

  pinned = "aa5550e64d8486ee8329ee9320fc82452e4eb0c2";
  hasPrefix = pkgs.lib.hasPrefix;

  logseqServers = pkgs.lib.filterAttrs (n: _: hasPrefix "logseq-" n) servers;

  contract = name: server: let
    e = server.environment;
    get = k: if e ? ${k} then e.${k} else null;
    # The grant for a `logseq-summ-<parent>` server lives on the `<parent>-kbn`
    # counterpart AGENT; for regular servers it is the profile-named agent.
    agent =
      if builtins.match "logseq-summ-.*" name != null
      then "${builtins.replaceStrings ["logseq-summ-"] [""] name}-kbn"
      else builtins.replaceStrings ["logseq-"] [""] name;
    agentTools = settings.agent.${agent}.tools or {};
    grant = builtins.filter (hasPrefix "logseq-") (builtins.attrNames agentTools);
  in {
    server = name;
    agent = agent;
    hostPort = server.hostPort;
    LOGSEQ_WRITE_INCLUDES = get "LOGSEQ_WRITE_INCLUDES";
    LOGSEQ_INCLUDE_NAMESPACES = get "LOGSEQ_INCLUDE_NAMESPACES";
    LOGSEQ_EXCLUDE_NAMESPACES = get "LOGSEQ_EXCLUDE_NAMESPACES";
    stdioPin = pinned;
    stdioCommand = server.stdioCommand;
    volumes = server.volumes or [];
    logseqToolGrant = grant;
  };

  report = builtins.mapAttrs (name: server: contract name server) logseqServers;
in
  builtins.toJSON report