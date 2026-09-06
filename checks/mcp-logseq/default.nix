{
  pkgs,
  lib,
  namespace,
  ...
}: let
  # mcp-logseq derivation check (module-derived ACL contract assertion).
  #
  # Evaluates the REAL modules/home/apps/ai-assistance/opencode/mcp.nix module
  # (import { lib; config; } directly) so the internal `let` bindings
  # (resolveSets, profileExcludes, mkLogseqServer, ...) evaluate faithfully, then
  # asserts:
  #   - the 7-server env oracle (ports, WRITE/INCLUDE/EXCLUDE strings, stdio
  #     pin, LOGSEQ_API_URL, environmentFile) of docs/guides/logseq-agent-namespaces.md,
  #   - the per-agent tool-grant isolation invariant (no cross-agent logseq glob)
  #     including the <agent>-kbn summarizer counterparts,
  #   - the counterpart delegation wiring (each parent grants exactly its own
  #     <agent>-kbn via permission.task; counterparts are subagents with the
  #     exact {logseq-kbn*, logseq-<parent>*} glob set),
  #   - that the three global namespace options resolve identically from
  #     modules/home/apps/ai-assistance/opencode/logseq-profiles.nix.
  # Any mismatch aborts loudly, so `nix build .#checks.<system>.mcp-logseq` fails.
  #
  # Run:
  #   nix build .#checks.x86_64-linux.mcp-logseq
  #
  # Per-host glue (logseqEnvironmentFile / logseqHost) is a fixture mirroring
  # homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode/default.nix; the
  # global namespace values come from logseq-profiles.nix itself.

  repoRoot = ../..;
  modulePath = repoRoot + "/modules/home/apps/ai-assistance/opencode/mcp.nix";
  profilesPath = repoRoot + "/modules/home/apps/ai-assistance/opencode/logseq-profiles.nix";

  # Host glue fixture (kept in sync with the salt sops-opencode module).
  mcpEnvFile = "/run/tmp/logseq-mcp.env";
  logseqHost = "salt";

  inherit
    (lib)
    hasPrefix
    attrNames
    concatStringsSep
    any
    all
    filterAttrs
    sort
    ;
  lessThan = builtins.lessThan;

  # Source the global namespace values from the real logseq-profiles.nix module.
  profileLib = lib // {
    mkDefault = x: x;
    ${namespace} = lib // {
      mkIfEnabled = _: module: module;
    };
  };
  profileVals = (import profilesPath {
    lib = profileLib;
    inherit namespace;
  }).${namespace}.ai-assistance.opencode.mcp;

  # Option defaults are NOT auto-applied outside the module system: merge each
  # profile's defaults ourselves (writeSets/readSets = [], readAllAgentOwns = false).
  withDefaults = _: prof:
    prof
    // {
      writeSets = prof.writeSets or [];
      readSets = prof.readSets or [];
      readAllAgentOwns = prof.readAllAgentOwns or false;
    };

  profiles = builtins.mapAttrs withDefaults profileVals.logseqAgentProfiles;

  # Overlay mkIf so the plain `settings` config body (agent/tools/mcp) is
  # readable. Both enable conditions are true under `providedConfig`, so
  # `mkIf _ x = x` preserves the body verbatim. Mock the namespace lib so the
  # module's `lib.<namespace>.mkIfEnabled` (if ever exercised) applies its
  # module body unconditionally instead of silently no-oping.
  moduleLib = lib // {
    mkIf = _: x: x;
    ${namespace} = lib // {
      mkIfEnabled = _opts: module: {config = module;};
    };
  };

  providedConfig = {
    programs.opencode.enable = true;
    programs.opencode.mcpContainers = {
      enable = true;
      accessMode = "host";
    };
    "ds-omega".ai-assistance.opencode.mcp = {
      logseqEnvironmentFile = mcpEnvFile;
      inherit logseqHost;
      logseqSharedNamespaces = profileVals.logseqSharedNamespaces;
      logseqNamespaceSets = profileVals.logseqNamespaceSets;
      logseqAgentProfiles = profiles;
    };
  };

  module = import modulePath;
  m = module {
    lib = moduleLib;
    config = providedConfig;
  };

  servers = m.options.programs.opencode.mcpContainers.servers.default;
  settings = m.config.programs.opencode.settings;

  # Assertion helper: fails the whole eval loudly when a condition is false.
  check = name: cond: msg:
    if cond
    then true
    else builtins.abort "mcp-logseq FAIL: ${name}: ${msg}";

  envGet = env: k: if env ? ${k} then env.${k} else null;
  splitCsv = s: builtins.filter (x: x != "") (builtins.split "," s);

  pinned = "aa5550e64d8486ee8329ee9320fc82452e4eb0c2";
  apiUrl = "http://${logseqHost}:12315";

  logseqServers = filterAttrs (n: _: hasPrefix "logseq-" n) servers;
  logseqServerNames = attrNames logseqServers;

  expectedNames = sort lessThan [
    "logseq-build"
    "logseq-docs-writer"
    "logseq-kbn"
    "logseq-nix-build"
    "logseq-nix-plan"
    "logseq-orchestrator"
    "logseq-plan"
  ];

  markerProfiles = ["plan" "nix-plan" "kbn"];
  strictProfiles = ["build" "docs-writer" "nix-build" "orchestrator"];
  profileOfServer = name: builtins.replaceStrings ["logseq-"] [""] name;
  rawSetNames = attrNames profileVals.logseqNamespaceSets;

  # ---------------------------------------------------------------------------
  # Counterpart model.
  # ---------------------------------------------------------------------------
  producingParents = ["build" "plan" "nix-build" "nix-plan" "docs-writer"];
  counterparts = map (p: "${p}-kbn") producingParents;

  # Every PURE agent must carry exactly {logseq-<own>*}.
  pureAgents = producingParents ++ ["kbn" "orchestrator"];
  # Counterparts carry exactly {logseq-kbn*, logseq-<parent>*}.
  parentOf = name: builtins.replaceStrings ["-kbn"] [""] name;

  allAgentNames = pureAgents ++ counterparts;

  # ---------------------------------------------------------------------------
  # The full oracle env per server (write / include / exclude).
  # ---------------------------------------------------------------------------
  expected = {
    "logseq-build" = {
      hostPort = 18108;
      write = "ai-bld Builder_system,ai Agents_system,ai-s-bld shared-Builder_system";
      include = null;
      exclude = null;
    };
    "logseq-docs-writer" = {
      hostPort = 18110;
      write = "ai-dwt DocsWriter_system,ai Agents_system";
      include = null;
      exclude = null;
    };
    "logseq-kbn" = {
      hostPort = 18103;
      write = "ai-kbn KnowledgeBaseNoter_system,ai Agents_system,ai-s-pln shared-Planner_system,personal";
      include = null;
      exclude = "ai-bld Builder_system,ai-dwt DocsWriter_system,ai-nxb NixBuilder_system,ai-nxp NixPlanner_system,ai-orc Orchestrator_system,ai-pln Planner_system,ai-s-bld shared-Builder_system";
    };
    "logseq-nix-build" = {
      hostPort = 18111;
      write = "ai-nxb NixBuilder_system,ai Agents_system,ai-s-bld shared-Builder_system";
      include = null;
      exclude = null;
    };
    "logseq-nix-plan" = {
      hostPort = 18112;
      write = "ai-nxp NixPlanner_system,ai Agents_system,ai-s-pln shared-Planner_system";
      include = "personal";
      exclude = "ai-bld Builder_system,ai-dwt DocsWriter_system,ai-kbn KnowledgeBaseNoter_system,ai-nxb NixBuilder_system,ai-orc Orchestrator_system,ai-pln Planner_system,ai-s-bld shared-Builder_system";
    };
    "logseq-orchestrator" = {
      hostPort = 18113;
      write = "ai-orc Orchestrator_system,ai Agents_system";
      include = "ai-bld Builder_system,ai-dwt DocsWriter_system,ai-kbn KnowledgeBaseNoter_system,ai-nxb NixBuilder_system,ai-nxp NixPlanner_system,ai-pln Planner_system";
      exclude = null;
    };
    "logseq-plan" = {
      hostPort = 18109;
      write = "ai-pln Planner_system,ai Agents_system,ai-s-pln shared-Planner_system";
      include = "personal";
      exclude = "ai-bld Builder_system,ai-dwt DocsWriter_system,ai-kbn KnowledgeBaseNoter_system,ai-nxb NixBuilder_system,ai-nxp NixPlanner_system,ai-orc Orchestrator_system,ai-s-bld shared-Builder_system";
    };
  };

  # Validate one server against the oracle + common invariants (7 & 8).
  checkServer = name: exp: let
    svc = logseqServers.${name};
    env = svc.environment;
    joinedCmd = concatStringsSep " " svc.stdioCommand;
    matches = var: want:
      if want == null then envGet env var == null else envGet env var == want;
  in
    check "${name}/exists" (svc != null) "server not derived"
    && check "${name}/hostPort" (svc.hostPort == exp.hostPort)
      "expected ${toString exp.hostPort} got ${toString svc.hostPort}"
    && check "${name}/write" (matches "LOGSEQ_WRITE_INCLUDES" exp.write)
      "expected '${toString exp.write}' got '${toString (envGet env "LOGSEQ_WRITE_INCLUDES")}'"
    && check "${name}/include" (matches "LOGSEQ_INCLUDE_NAMESPACES" exp.include)
      "expected '${toString exp.include}' got '${toString (envGet env "LOGSEQ_INCLUDE_NAMESPACES")}'"
    && check "${name}/exclude" (matches "LOGSEQ_EXCLUDE_NAMESPACES" exp.exclude)
      "expected '${toString exp.exclude}' got '${toString (envGet env "LOGSEQ_EXCLUDE_NAMESPACES")}'"
    && check "${name}/apiUrl" (env.LOGSEQ_API_URL == apiUrl)
      "expected '${apiUrl}' got '${env.LOGSEQ_API_URL}'"
    && check "${name}/sopsEnvFile"
      (svc.environmentFile == mcpEnvFile)
      "expected '${mcpEnvFile}' got '${toString svc.environmentFile}'"
    && check "${name}/stdioPin" (builtins.match ".*${pinned}.*" joinedCmd != null)
      "stdioCommand must pin ${pinned}; got: ${joinedCmd}";

  # ---------------------------------------------------------------------------
  # Invariant 1.
  # ---------------------------------------------------------------------------
  assertNoGeneric = check "no generic 'logseq' server"
    (!(servers ? logseq))
    "a bare 'logseq' server must not exist";

  assertNamedServers = check "exactly the 7 expected logseq servers"
    (logseqServerNames == expectedNames)
    "expected [${concatStringsSep "," expectedNames}] got [${concatStringsSep "," logseqServerNames}]";

  assertToolsGlobOff = check "settings.tools.logseq* == false"
    (settings.tools."logseq*" == false)
    "settings.tools.logseq* must be false";

  assertMcpoDisabled = check "logseq-mcpo disabled"
    (settings.mcp ? "logseq-mcpo" && settings.mcp."logseq-mcpo".enabled == false)
    "logseq-mcpo must be disabled";

  # ---------------------------------------------------------------------------
  # Invariant 2 & 3: excludes exist ONLY for marker profiles; never a raw
  # set NAME (e.g. `buildPair`); always the RESOLVED namespace.
  # ---------------------------------------------------------------------------
  assertExcludes = all (name: let
    prof = profileOfServer name;
    isMarker = builtins.elem prof markerProfiles;
    exclude = envGet logseqServers.${name}.environment "LOGSEQ_EXCLUDE_NAMESPACES";
    tokens = if exclude == null then [] else splitCsv exclude;
  in
    check "${name}/excludeDerivation"
      (if isMarker then exclude != null else exclude == null)
      "exclude must exist for marker profile and be absent for strict (marker=${toString isMarker})"
    && check "${name}/excludeResolvedOnly"
      (all (raw: ! builtins.elem raw tokens) rawSetNames)
      "exclude must never contain a raw set name; got ${toString tokens}") logseqServerNames;

  # ---------------------------------------------------------------------------
  # Invariant 4: `personal` marker pairs with a non-empty exclude (same server).
  # ---------------------------------------------------------------------------
  checkPersonalPair = name: let
    env = logseqServers.${name}.environment;
    w = envGet env "LOGSEQ_WRITE_INCLUDES";
    i = envGet env "LOGSEQ_INCLUDE_NAMESPACES";
    e = envGet env "LOGSEQ_EXCLUDE_NAMESPACES";
    hasPersonal =
      (w != null && builtins.elem "personal" (splitCsv w))
      || (i != null && builtins.elem "personal" (splitCsv i));
  in
    check "${name}/personalPairsWithExclude"
      (if hasPersonal then e != null else e == null)
      "if 'personal' appears, exclude must be non-empty; if absent, exclude must be absent";

  assertPersonalPair = all (name: checkPersonalPair name) logseqServerNames;

  # ---------------------------------------------------------------------------
  # Invariant 5: strict profiles carry no `personal` and no exclude.
  # ---------------------------------------------------------------------------
  assertStrictClean = all (name: let
    env = logseqServers.${"logseq-${name}"}.environment;
    w = envGet env "LOGSEQ_WRITE_INCLUDES";
    i = envGet env "LOGSEQ_INCLUDE_NAMESPACES";
    e = envGet env "LOGSEQ_EXCLUDE_NAMESPACES";
    hasPersonal =
      (w != null && builtins.elem "personal" (splitCsv w))
      || (i != null && builtins.elem "personal" (splitCsv i));
  in
    check "strict/${name}" (e == null && ! hasPersonal)
      "strict profile must have no excludes and no personal marker") strictProfiles;

  # ---------------------------------------------------------------------------
  # Invariant 6: orchestrator include == exactly every OTHER profile's own.
  # (attrValues on filterAttrs yields values sorted by key, so sort the owns.)
  # ---------------------------------------------------------------------------
  otherOwns = let
    sortedProfiles = sort lessThan (attrNames profiles);
  in
    map (p: profiles.${p}.own) (
      builtins.filter (p: p != "orchestrator") sortedProfiles
    );

  assertOrchestratorInclude = check "orchestrator include == other owns"
    (let
      inc = envGet logseqServers."logseq-orchestrator".environment "LOGSEQ_INCLUDE_NAMESPACES";
      want = concatStringsSep "," otherOwns;
    in
      inc == want)
    "orchestrator include must be exactly every other profile's own tree";

  # ---------------------------------------------------------------------------
  # Invariant 9 + new: per-agent tool grants; isolation; counterpart glob sets.
  # ---------------------------------------------------------------------------
  logseqGlobsOf = name: sort lessThan (
    builtins.filter (hasPrefix "logseq-") (attrNames (settings.agent.${name}.tools or {}))
  );

  # For pure agents the only allowed glob is {logseq-<own>*}.
  checkPureAgent = name:
    check "agent/${name} isolation" (logseqGlobsOf name == ["logseq-${name}*"])
      "expected exactly [logseq-${name}*] got [${concatStringsSep "," (logseqGlobsOf name)}]";

  # For counterparts: exactly {logseq-kbn*, logseq-<parent>*}.
  checkCounterpart = name: let
    want = sort lessThan ["logseq-kbn*" "logseq-${parentOf name}*"];
  in
    check "counterpart/${name} globs" (logseqGlobsOf name == want)
      "expected [${concatStringsSep "," want}] got [${concatStringsSep "," (logseqGlobsOf name)}]";

  assertIsolation = all (name:
    if builtins.elem name counterparts
    then checkCounterpart name
    else checkPureAgent name
  ) allAgentNames;

  # ---------------------------------------------------------------------------
  # Invariant (new): delegation via permission.task.
  # ---------------------------------------------------------------------------
  assertDelegation = all (name: let
    task = (settings.agent.${name}.permission or {}).task or {};
  in
    check "parent/${name} delegates one counterpart" (attrNames task == ["${name}-kbn"])
      "expected exactly [${name}-kbn] got [${concatStringsSep "," (attrNames task)}]"
    && check "parent/${name} task allow"
      (task."${name}-kbn" == "allow")
      "expected allow for ${name}-kbn") producingParents;

  # Counterpart personas live in `settings.agent` (mcp.nix): mode subagent,
  # hidden, description, bash denied.
  assertCounterpartPersona = all (name: let
    agent = settings.agent.${name};
  in
    check "counterpart/${name} mode" (agent.mode == "subagent")
      "counterpart must be mode: subagent"
    && check "counterpart/${name} hidden" (agent.hidden == true)
      "counterpart must be hidden: true"
    && check "counterpart/${name} bash denied"
      ((agent.permission or {}) ? bash && agent.permission.bash == "deny")
      "counterpart must deny bash"
    && check "counterpart/${name} description" (builtins.isString (agent.description or null))
      "counterpart must have a description") counterparts;

  # ---------------------------------------------------------------------------
  # Invariant (new): the three global options resolve identically to the known
  # values via logseq-profiles.nix (they moved out of the salt host file).
  # ---------------------------------------------------------------------------
  expectedProfiles = {
    kbn = {
      own = "ai-kbn KnowledgeBaseNoter_system";
      writeSets = ["planPair" "personal"];
      readSets = [];
      readAllAgentOwns = false;
    };
    build = {
      own = "ai-bld Builder_system";
      writeSets = ["buildPair"];
      readSets = [];
      readAllAgentOwns = false;
    };
    plan = {
      own = "ai-pln Planner_system";
      writeSets = ["planPair"];
      readSets = ["personal"];
      readAllAgentOwns = false;
    };
    docs-writer = {
      own = "ai-dwt DocsWriter_system";
      writeSets = [];
      readSets = [];
      readAllAgentOwns = false;
    };
    nix-build = {
      own = "ai-nxb NixBuilder_system";
      writeSets = ["buildPair"];
      readSets = [];
      readAllAgentOwns = false;
    };
    nix-plan = {
      own = "ai-nxp NixPlanner_system";
      writeSets = ["planPair"];
      readSets = ["personal"];
      readAllAgentOwns = false;
    };
    orchestrator = {
      own = "ai-orc Orchestrator_system";
      writeSets = [];
      readSets = [];
      readAllAgentOwns = true;
    };
  };

  assertProfilesFromModule = check "logseq-profiles values"
    (profiles == expectedProfiles)
    "profiles from logseq-profiles.nix must equal the documented values";

  assertSharedFromModule = check "logseqSharedNamespaces == ai Agents_system"
    (profileVals.logseqSharedNamespaces == ["ai Agents_system"])
    "logseqSharedNamespaces must be ['ai Agents_system']";

  assertSetsFromModule = check "logseqNamespaceSets == buildPair/planPair"
    (profileVals.logseqNamespaceSets == {
      buildPair = ["ai-s-bld shared-Builder_system"];
      planPair = ["ai-s-pln shared-Planner_system"];
    })
    "logseqNamespaceSets must contain buildPair and planPair";
in
  assert assertNoGeneric;
  assert assertNamedServers;
  assert (all (name: checkServer name expected.${name}) expectedNames);
  assert assertToolsGlobOff;
  assert assertMcpoDisabled;
  assert assertExcludes;
  assert assertPersonalPair;
  assert assertStrictClean;
  assert assertOrchestratorInclude;
  assert assertIsolation;
  assert assertDelegation;
  assert assertCounterpartPersona;
  assert assertProfilesFromModule;
  assert assertSharedFromModule;
  assert assertSetsFromModule;
  # Asserts above force evaluation of every invariant (aborting on mismatch),
  # so this trivial derivation only exists to satisfy Snowfall check discovery
  # and to mark success.
  pkgs.runCommand "mcp-logseq-check" { }
    ''
      echo "mcp-logseq derivation checks OK" > "$out"
    ''