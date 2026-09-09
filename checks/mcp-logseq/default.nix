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
  #   - the 17-server env oracle (9 knowledge-role profiles + the
  #     `kbn-escalated` write-everywhere instance + 7 `<parent>-kbn`
  #     `logseq-summ-<parent>` summarizer instances; ports, WRITE/INCLUDE/
  #     EXCLUDE strings, stdio, LOGSEQ_API_URL, environmentFile),
  #   - the per-agent tool-grant isolation invariant (no cross-agent logseq glob)
  #     including the summarizer counterparts (dedicated `logseq-summ-<parent>*`
  #     instance only) and that DELIVERY agents (plan/build/nix-plan/nix-build/
  #     verifier) carry NO logseq glob at all,
  #   - the counterpart delegation wiring (each producing parent's
  #     `permission.task` is deny-*-kbn + allow exactly its own `<parent>-kbn`).
  #   - kbn's `readAllNamespaces` exception (personal marker with NO excludes).
  #   - the `kbn-escalated` `writeAllNamespaces` instance (write = the
  #     `personal` marker, NO excludes) and kbn's narrowed `logseq-kbn_*`
  #     grant with the escalated `logseq-kbn-escalated_*` tools gated behind
  #     an "ask" permission.
  #   - that the global namespace options resolve identically from
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
  # `inputs.mcp-logseq` is the Nix store source the real flake provides; here a
  # repo-relative stand-in path.
  mcpLogseqSrc = repoRoot + "/.";

  profileLib = lib // {
    mkDefault = x: x;
    ${namespace} = lib // {
      mkIfEnabled = _: module: module;
    };
  };
  profileVals = (import profilesPath {
    lib = profileLib;
    inherit namespace;
    inputs = {mcp-logseq = mcpLogseqSrc;};
  }).${namespace}.ai-assistance.opencode.mcp;

  # Option defaults are NOT auto-applied outside the module system: merge each
  # profile's defaults ourselves (writeSets/readSets/readAllAgentOwns/
  # readAllNamespaces/writeAllNamespaces).
  withDefaults = _: prof:
    prof
    // {
      writeSets = prof.writeSets or [];
      readSets = prof.readSets or [];
      readAllAgentOwns = prof.readAllAgentOwns or false;
      readAllNamespaces = prof.readAllNamespaces or false;
      writeAllNamespaces = prof.writeAllNamespaces or false;
    };

  profiles = builtins.mapAttrs withDefaults profileVals.logseqAgentProfiles;
  summarizerProfiles = builtins.mapAttrs withDefaults profileVals.logseqSummarizerProfiles;
  escalatedProfiles = builtins.mapAttrs withDefaults profileVals.logseqEscalatedProfiles;

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
      # Real option default (container registry incl. `// logseqAgentServers`);
      # Nix `let` is recursive so `m.options…` is reachable here.
      servers = m.options.programs.opencode.mcpContainers.servers.default;
    };
    "ds-omega".ai-assistance.opencode.mcp = {
      logseqEnvironmentFile = mcpEnvFile;
      inherit logseqHost;
      logseqSrc = mcpLogseqSrc;
      logseqSharedNamespaces = profileVals.logseqSharedNamespaces;
      logseqNamespaceSets = profileVals.logseqNamespaceSets;
      logseqAgentProfiles = profiles;
      logseqSummarizerProfiles = summarizerProfiles;
      logseqEscalatedProfiles = escalatedProfiles;
    };
  };

  module = import modulePath;
  m = module {
    lib = moduleLib;
    config = providedConfig;
  };

  servers = m.options.programs.opencode.mcpContainers.servers.default;
  settings = m.config.programs.opencode.settings;
  mcpServers = m.config.programs.mcp.servers;

  # Backward compatibility: with logseqSrc = null the module must keep the
  # git-URL stdio and derive NO source volume. Re-evaluate with a null src.
  providedConfigNoSrc = providedConfig // {
    "ds-omega".ai-assistance.opencode.mcp = providedConfig."ds-omega".ai-assistance.opencode.mcp // {logseqSrc = null;};
  };
  mNoSrc = module {lib = moduleLib; config = providedConfigNoSrc;};
  logseqServersNoSrc = filterAttrs (
    n: _: hasPrefix "logseq-" n
  ) mNoSrc.options.programs.opencode.mcpContainers.servers.default;

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
    # Knowledge-role instances.
    "logseq-analyst"
    "logseq-architect"
    "logseq-kbn"
    "logseq-kbn-escalated"
    "logseq-nix-analyst"
    "logseq-orchestrator"
    "logseq-reporter"
    "logseq-researcher"
    "logseq-strategist"
    "logseq-tactician"
    # Dedicated <parent>-kbn summarizer instances.
    "logseq-summ-analyst"
    "logseq-summ-architect"
    "logseq-summ-nix-analyst"
    "logseq-summ-reporter"
    "logseq-summ-researcher"
    "logseq-summ-strategist"
    "logseq-summ-tactician"
  ];

  markerProfiles = [
    "strategist" # personal via readSets
    # kbn is a readAllNamespaces profile → personal in include but NO excludes (see below).
  ];
  # readAllNamespaces profiles: personal marker WITHOUT excludes (deliberate kbn exception).
  globalReadProfiles = ["kbn"];
  # writeAllNamespaces profiles (escalated): `personal` WRITE marker WITHOUT
  # excludes — exempt from the personal⇒exclude pairing like globalReadProfiles.
  escalatedProfileNames = attrNames escalatedProfiles;
  # Strict profiles: no personal marker, no excludes.
  strictProfiles = [
    "orchestrator"
    "tactician"
    "architect"
    "researcher"
    "analyst"
    "nix-analyst"
    "reporter"
  ];
  profileOfServer = name: builtins.replaceStrings ["logseq-"] [""] name;
  rawSetNames = attrNames profileVals.logseqNamespaceSets;

  # ---------------------------------------------------------------------------
  # Summarizer (counterpart) model.
  # ---------------------------------------------------------------------------
  producingParents = [
    "strategist"
    "tactician"
    "architect"
    "researcher"
    "analyst"
    "nix-analyst"
    "reporter"
  ];
  counterparts = map (p: "${p}-kbn") producingParents;

  # Every knowledge agent carries exactly {logseq-<own>*} — except kbn (see
  # checkKnowledgeAgent: narrowed `logseq-kbn_*` + escalated glob).
  knowledgeAgents = producingParents ++ ["orchestrator" "kbn"];
  # Delivery agents carry NO logseq glob at all.
  deliveryAgents = ["plan" "nix-plan" "build" "nix-build" "verifier"];
  parentOf = name: builtins.replaceStrings ["-kbn"] [""] name;
  summOf = name: "summ-${parentOf name}";

  allAgentNames = knowledgeAgents ++ counterparts ++ deliveryAgents;

  # ---------------------------------------------------------------------------
  # The full oracle env per server (write / include / exclude).
  # ---------------------------------------------------------------------------
  shared = "ai Agents_system";
  discovery = "ai-shared-Discovery_system";
  architecture = "ai-shared-Architecture_system";
  expected = {
    "logseq-orchestrator" = {
      hostPort = 18113;
      write = "ai-orc Orchestrator_system,${shared}";
      include = "${discovery},${architecture},ai-anl Analyst_system,ai-arc Architect_system,ai-kbn KnowledgeBaseNoter_system,ai-nxl NixAnalyst_system,ai-rpt Reporter_system,ai-rsh Researcher_system,ai-str Strategist_system,ai-tcn Tactician_system";
      exclude = null;
    };
    "logseq-strategist" = {
      hostPort = 18108;
      write = "ai-str Strategist_system,${shared},${discovery}";
      include = "personal,${architecture}";
      exclude = "ai-anl Analyst_system,ai-arc Architect_system,ai-kbn KnowledgeBaseNoter_system,ai-nxl NixAnalyst_system,ai-orc Orchestrator_system,ai-rpt Reporter_system,ai-rsh Researcher_system,ai-tcn Tactician_system,ai-s-bld shared-Builder_system,ai-bld Builder_system,ai-nxb NixBuilder_system,ai-nxp NixPlanner_system,ai-pln Planner_system,ai-s-pln shared-Planner_system";
    };
    "logseq-tactician" = {
      hostPort = 18109;
      write = "ai-tcn Tactician_system,${shared}";
      include = "${discovery},${architecture},ai-anl Analyst_system,ai-arc Architect_system,ai-kbn KnowledgeBaseNoter_system,ai-nxl NixAnalyst_system,ai-orc Orchestrator_system,ai-rpt Reporter_system,ai-rsh Researcher_system,ai-str Strategist_system";
      exclude = null;
    };
    "logseq-architect" = {
      hostPort = 18110;
      write = "ai-arc Architect_system,${shared},${architecture}";
      include = "${discovery},${architecture}";
      exclude = null;
    };
    "logseq-researcher" = {
      hostPort = 18111;
      write = "ai-rsh Researcher_system,${shared}";
      include = "${discovery},${architecture}";
      exclude = null;
    };
    "logseq-analyst" = {
      hostPort = 18112;
      write = "ai-anl Analyst_system,${shared},ai-pln Planner_system,ai-s-pln shared-Planner_system";
      include = "${discovery},${architecture}";
      exclude = null;
    };
    "logseq-nix-analyst" = {
      hostPort = 18114;
      write = "ai-nxl NixAnalyst_system,${shared},ai-nxp NixPlanner_system";
      include = "${discovery},${architecture}";
      exclude = null;
    };
    "logseq-reporter" = {
      hostPort = 18115;
      write = "ai-rpt Reporter_system,${shared},ai-bld Builder_system,ai-nxb NixBuilder_system,ai-s-bld shared-Builder_system";
      include = "${discovery},${architecture}";
      exclude = null;
    };
    "logseq-kbn" = {
      hostPort = 18103;
      write = "ai-kbn KnowledgeBaseNoter_system,${shared}";
      include = "personal";
      exclude = null;
    };
    # Escalated write-everywhere instance (writeAllNamespaces): WRITE
    # collapses to the `personal` complement marker (subsumes own/shared/sets),
    # READ = every namespace, and — like kbn — NO excludes.
    "logseq-kbn-escalated" = {
      hostPort = 18123;
      write = "personal";
      include = "personal";
      exclude = null;
    };
    # Dedicated summarizer instances (one per producing parent): WRITE the
    # parent's own `<parent-own>/_journals` tree (+ the global shared tree);
    # READ the parent's own tree only. NO personal, NO broad kbn instance,
    # NO excludes.
    "logseq-summ-strategist" = {
      hostPort = 18116;
      write = "ai-str Strategist_system/_journals,${shared}";
      include = "ai-str Strategist_system";
      exclude = null;
    };
    "logseq-summ-tactician" = {
      hostPort = 18117;
      write = "ai-tcn Tactician_system/_journals,${shared}";
      include = "ai-tcn Tactician_system";
      exclude = null;
    };
    "logseq-summ-architect" = {
      hostPort = 18118;
      write = "ai-arc Architect_system/_journals,${shared}";
      include = "ai-arc Architect_system";
      exclude = null;
    };
    "logseq-summ-researcher" = {
      hostPort = 18119;
      write = "ai-rsh Researcher_system/_journals,${shared}";
      include = "ai-rsh Researcher_system";
      exclude = null;
    };
    "logseq-summ-analyst" = {
      hostPort = 18120;
      write = "ai-anl Analyst_system/_journals,${shared}";
      include = "ai-anl Analyst_system";
      exclude = null;
    };
    "logseq-summ-nix-analyst" = {
      hostPort = 18121;
      write = "ai-nxl NixAnalyst_system/_journals,${shared}";
      include = "ai-nxl NixAnalyst_system";
      exclude = null;
    };
    "logseq-summ-reporter" = {
      hostPort = 18122;
      write = "ai-rpt Reporter_system/_journals,${shared}";
      include = "ai-rpt Reporter_system";
      exclude = null;
    };
  };

  # Validate one server against the oracle + common invariants.
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
    && check "${name}/stdioLocal"
      (svc.stdioCommand == ["uvx" "--refresh" "--from" "/app/mcp-logseq" "mcp-logseq"])
      "with logseqSrc set, stdio must be 'uvx --refresh --from /app/mcp-logseq mcp-logseq'; got '${joinedCmd}'"
    && check "${name}/srcVolume"
      (builtins.elem "${mcpLogseqSrc}:/app/mcp-logseq:ro" (svc.volumes or []))
      "expected source mount volume '${mcpLogseqSrc}:/app/mcp-logseq:ro'; got '${concatStringsSep "," (svc.volumes or [])}'";

  # ---------------------------------------------------------------------------
  # Invariant 1.
  # ---------------------------------------------------------------------------
  assertNoGeneric = check "no generic bare 'logseq' server"
    (!(servers ? logseq))
    "a bare 'logseq' server must not exist (only logseq-<profile> and the disabled logseq-mcpo)";

  assertBackwardCompat = all (name: let
    svc = logseqServersNoSrc.${name};
    joined = concatStringsSep " " svc.stdioCommand;
  in
    check "backcompat/${name} stdio keeps git url"
      (builtins.match ".*${pinned}.*" joined != null)
      "without logseqSrc stdio must keep the git URL; got '${joined}'"
    && check "backcompat/${name} no src volume"
      ((svc.volumes or []) == [])
      "without logseqSrc there must be no src volume") expectedNames;

  assertNamedServers = check "exactly the 17 expected logseq servers"
    (logseqServerNames == expectedNames)
    "expected [${concatStringsSep "," expectedNames}] got [${concatStringsSep "," logseqServerNames}]";

  assertToolsGlobOff = check "settings.tools.logseq* == false"
    (settings.tools."logseq*" == false)
    "settings.tools.logseq* must be false";

  assertNoGenericMcpoInSettings = check "logseq-mcpo registered but DISABLED in opencode"
    (mcpServers ? logseq-mcpo
      && settings.mcp ? "logseq-mcpo"
      && settings.mcp."logseq-mcpo".enabled == false)
    "logseq-mcpo must stay registered (other consumers) but be disabled in OpenCode";

  # ---------------------------------------------------------------------------
  # Invariant 2 & 3: excludes exist ONLY for marker profiles (personal via
  # readSets/writeSets); NEVER a raw set NAME; always the RESOLVED namespace.
  # readAllNamespaces profiles are the deliberate exception: personal marker
  # in include, NO excludes.
  # ---------------------------------------------------------------------------
  assertExcludes = all (name: let
    prof = profileOfServer name;
    isMarker = builtins.elem prof markerProfiles;
    isGlobal = builtins.elem prof globalReadProfiles;
    exclude = envGet logseqServers.${name}.environment "LOGSEQ_EXCLUDE_NAMESPACES";
    tokens = if exclude == null then [] else splitCsv exclude;
  in
    check "${name}/excludeDerivation"
      (if isMarker then exclude != null else exclude == null)
      "exclude must exist for marker profile, be absent for strict and be absent for readAllNamespaces"
    && check "${name}/globalReadNoExclude"
      (if isGlobal then exclude == null else true)
      "readAllNamespaces profile must have NO excludes"
    && check "${name}/excludeResolvedOnly"
      (all (raw: ! builtins.elem raw tokens) rawSetNames)
      "exclude must never contain a raw set name; got ${toString tokens}") logseqServerNames;

  # ---------------------------------------------------------------------------
  # Invariant 4: `personal` marker pairs with a non-empty exclude, EXCEPT for
  # readAllNamespaces profiles (kbn) which intentionally read the whole graph.
  # ---------------------------------------------------------------------------
  checkPersonalPair = name: let
    env = logseqServers.${name}.environment;
    prof = profileOfServer name;
    w = envGet env "LOGSEQ_WRITE_INCLUDES";
    i = envGet env "LOGSEQ_INCLUDE_NAMESPACES";
    e = envGet env "LOGSEQ_EXCLUDE_NAMESPACES";
    hasPersonal =
      (w != null && builtins.elem "personal" (splitCsv w))
      || (i != null && builtins.elem "personal" (splitCsv i));
    isGlobal = builtins.elem prof globalReadProfiles;
    isEscalated = builtins.elem prof escalatedProfileNames;
  in
    check "${name}/personalPairsWithExclude"
      (if hasPersonal && ! isGlobal && ! isEscalated then e != null else true)
      "non-exempt profile with 'personal' must have excludes; readAllNamespaces (kbn) and writeAllNamespaces (kbn-escalated) are exempt without"
    && check "${name}/globalReadPersonalOnly"
      (if isGlobal then i != null && builtins.elem "personal" (splitCsv i) else true)
      "readAllNamespaces profile must carry the personal marker in include";

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
  # Invariant 6: orchestrator/tactician include == readSets resolved + every
  # OTHER profile's own tree.
  # ---------------------------------------------------------------------------
  readAllOwnsIncludes = name: let
    o = (builtins.filter (p: p != name) (sort lessThan (attrNames profiles)));
  in
    (concatStringsSep "," [
      discovery
      architecture
    ])
    + ","
    + concatStringsSep "," (map (p: profiles.${p}.own) o);

  assertOrchestratorInclude = check "orchestrator include == discovery/research?? own tree"
    (let
      inc = envGet logseqServers."logseq-orchestrator".environment "LOGSEQ_INCLUDE_NAMESPACES";
      want = readAllOwnsIncludes "orchestrator";
    in
      inc == want)
    "orchestrator include must be discovery+architecture then every other profile's own tree";

  assertTacticianInclude = check "tactician include == discovery/architecture + other owns"
    (let
      inc = envGet logseqServers."logseq-tactician".environment "LOGSEQ_INCLUDE_NAMESPACES";
      want = readAllOwnsIncludes "tactician";
    in
      inc == want)
    "tactician include must be discovery+architecture then every other profile's own tree";

  # ---------------------------------------------------------------------------
  # Invariant 9 + delivery: per-agent tool grants; isolation; counterpart glob
  # sets; NO logseq glob on delivery agents.
  # ---------------------------------------------------------------------------
  logseqGlobsOf = name: sort lessThan (
    builtins.filter (hasPrefix "logseq-") (attrNames (settings.agent.${name}.tools or {}))
  );

  # For knowledge agents the only allowed glob is {logseq-<own>*} — except
  # kbn: its own glob is narrowed to `logseq-kbn_*` (so it cannot swallow the
  # escalated instance's tools; `-` < `_` lexicographically) and the escalated
  # glob is granted too, gated behind an "ask" permission.
  checkKnowledgeAgent = name:
    if name == "kbn"
    then
      check "agent/kbn isolation"
      (logseqGlobsOf name == ["logseq-kbn-escalated_*" "logseq-kbn_*"])
      "expected exactly [logseq-kbn-escalated_*,logseq-kbn_*] got [${concatStringsSep "," (logseqGlobsOf name)}]"
      && check "agent/kbn escalated ask permission"
      ((settings.agent.kbn.permission or {})."logseq-kbn-escalated_*" or null == "ask")
      "kbn must gate 'logseq-kbn-escalated_*' behind an ask permission"
    else
      check "agent/${name} isolation" (logseqGlobsOf name == ["logseq-${name}*"])
      "expected exactly [logseq-${name}*] got [${concatStringsSep "," (logseqGlobsOf name)}]";

  # For counterparts: exactly the dedicated summary instance {logseq-summ-<parent>*}.
  checkCounterpart = name: let
    want = ["logseq-${summOf name}*"];
  in
    check "counterpart/${name} globs" (logseqGlobsOf name == want)
      "expected [${concatStringsSep "," want}] got [${concatStringsSep "," (logseqGlobsOf name)}]";

  # Delivery agents (plan/build/nix-plan/nix-build/verifier): zero logseq globs.
  checkDeliveryNoLogseq = name:
    check "delivery/${name} no logseq" (logseqGlobsOf name == [])
      "delivery agent must carry NO logseq glob; got [${concatStringsSep "," (logseqGlobsOf name)}]";

  assertIsolation = all (name:
    if builtins.elem name counterparts
    then checkCounterpart name
    else if builtins.elem name deliveryAgents
    then checkDeliveryNoLogseq name
    else checkKnowledgeAgent name
  ) allAgentNames;

  # ---------------------------------------------------------------------------
  # Invariant (new): delegation via permission.task for producing parents.
  # ---------------------------------------------------------------------------
  assertDelegation = all (name: let
    task = (settings.agent.${name}.permission or {}).task or {};
    wantKeys = sort lessThan ["*-kbn" "${name}-kbn"];
  in
    check "parent/${name} task blocks other counterparts"
      (attrNames task == wantKeys)
      "expected exactly [${concatStringsSep "," wantKeys}] got [${concatStringsSep "," (attrNames task)}]"
    && check "parent/${name} task deny *-kbn"
      (task."*-kbn" == "deny")
      "task '*-kbn' must be deny"
    && check "parent/${name} task allow own counterpart"
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
  # Invariant: the global options resolve identically to the known values via
  # logseq-profiles.nix (they moved out of the salt host file).
  # ---------------------------------------------------------------------------
  expectedProfiles = {
    orchestrator = {
      own = "ai-orc Orchestrator_system";
      writeSets = [];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = true;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    strategist = {
      own = "ai-str Strategist_system";
      writeSets = ["discovery"];
      readSets = ["personal" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    tactician = {
      own = "ai-tcn Tactician_system";
      writeSets = [];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = true;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    architect = {
      own = "ai-arc Architect_system";
      writeSets = ["architecture"];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    researcher = {
      own = "ai-rsh Researcher_system";
      writeSets = [];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    analyst = {
      own = "ai-anl Analyst_system";
      writeSets = ["planOwn" "planPair"];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    nix-analyst = {
      own = "ai-nxl NixAnalyst_system";
      writeSets = ["nixPlanOwn"];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    reporter = {
      own = "ai-rpt Reporter_system";
      writeSets = ["builderOwn" "nixBuilderOwn" "buildPair"];
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    };
    kbn = {
      own = "ai-kbn KnowledgeBaseNoter_system";
      writeSets = [];
      readSets = [];
      readAllAgentOwns = false;
      readAllNamespaces = true;
      writeAllNamespaces = false;
    };
  };

  assertProfilesFromModule = check "logseq-profiles values"
    (profiles == expectedProfiles)
    "profiles from logseq-profiles.nix must equal the documented values";

  assertSharedFromModule = check "logseqSharedNamespaces == ai Agents_system"
    (profileVals.logseqSharedNamespaces == ["ai Agents_system"])
    "logseqSharedNamespaces must be ['ai Agents_system']";

  assertSetsFromModule = check "logseqNamespaceSets == the 8 documented bundles"
    (profileVals.logseqNamespaceSets == {
      planOwn = ["ai-pln Planner_system"];
      nixPlanOwn = ["ai-nxp NixPlanner_system"];
      builderOwn = ["ai-bld Builder_system"];
      nixBuilderOwn = ["ai-nxb NixBuilder_system"];
      buildPair = ["ai-s-bld shared-Builder_system"];
      planPair = ["ai-s-pln shared-Planner_system"];
      discovery = ["ai-shared-Discovery_system"];
      architecture = ["ai-shared-Architecture_system"];
    })
    "logseqNamespaceSets must contain exactly the 8 documented bundles";

  summOwn = p: profiles.${p}.own + "/_journals";
  expectedSummarizers = builtins.listToAttrs (map (p:
    lib.nameValuePair "summ-${p}" {
      own = summOwn p;
      writeSets = [];
      readSets = [];
      readAllAgentOwns = false;
      readAllNamespaces = false;
      writeAllNamespaces = false;
    }) producingParents);

  assertSummFromModule = check "logseqSummarizerProfiles values"
    (summarizerProfiles == expectedSummarizers)
    "summarizer profiles must match the documented values";

  expectedEscalatedProfiles = {
    kbn-escalated = {
      own = "ai-kbn KnowledgeBaseNoter_system";
      writeSets = [];
      readSets = [];
      readAllAgentOwns = false;
      readAllNamespaces = true;
      writeAllNamespaces = true;
    };
  };

  assertEscalatedFromModule = check "logseqEscalatedProfiles values"
    (escalatedProfiles == expectedEscalatedProfiles)
    "escalated profiles must match the documented values";
in
  assert assertNoGeneric;
  assert assertBackwardCompat;
  assert assertNamedServers;
  assert (all (name: checkServer name expected.${name}) expectedNames);
  assert assertToolsGlobOff;
  assert assertNoGenericMcpoInSettings;
  assert assertExcludes;
  assert assertPersonalPair;
  assert assertStrictClean;
  assert assertOrchestratorInclude;
  assert assertTacticianInclude;
  assert assertIsolation;
  assert assertDelegation;
  assert assertCounterpartPersona;
  assert assertProfilesFromModule;
  assert assertSharedFromModule;
  assert assertSetsFromModule;
  assert assertSummFromModule;
  assert assertEscalatedFromModule;
  # Asserts above force evaluation of every invariant (aborting on mismatch),
  # so this trivial derivation only exists to satisfy Snowfall check discovery
  # and to mark success.
  pkgs.runCommand "mcp-logseq-check" { }
    ''
      echo "mcp-logseq derivation checks OK" > "$out"
    ''