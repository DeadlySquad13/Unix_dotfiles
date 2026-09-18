# OpenCode plugin for persistent SSH sessions, built by Nix from the
# rev-pinned `opencode-ssh-session` flake input so OpenCode never has to
# npm-install it at startup (see `modules/home/apps/ai-assistance/opencode
# /ssh-session-plugin/default.nix` for the `file://` wiring).
#
# The dist bundle is SELF-CONTAINED: the runtime dependency
# `@opencode-ai/plugin` (which re-exports `tool`/`tool.schema` from zod) is
# vendored from the rev-pinned `opencode` flake input (OpenCode v1.2.5,
# `packages/plugin`), and zod (the SDK's only runtime dependency, catalog
# version 4.1.8) is vendored from a hash-pinned fetchFromGitHub. A bare
# `import "@opencode-ai/plugin"` is NOT resolved by the OpenCode host for
# `file://` plugins, and Bun's fallback silently attempts an npm install
# (unreachable network here), hanging startup — hence full vendoring. After
# bundling, the only remaining imports are node builtins and `Bun.*` APIs.
{
  lib,
  inputs,
  fetchFromGitHub,
  stdenv,
  bun,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "opencode-ssh-session";

  version = "0.3.0";

  src = inputs.opencode-ssh-session;

  # zod 4.1.8 — the version pinned by OpenCode v1.2.5's package catalog
  # (`zod: "4.1.8"`), which the vendored `@opencode-ai/plugin` SDK is written
  # against. Rev is the `v4.1.8` tag of colinhacks/zod.
  zodSrc = fetchFromGitHub {
    owner = "colinhacks";
    repo = "zod";
    rev = "a1726d53172ba52ecf90999df73778cf416264fd";
    hash = "sha256-/UJgDOFZQXsNX2N6XRkbnqB4EstTAy2clxAGjKKC3bc=";
  };

  nativeBuildInputs = [bun];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR

    # Vendor `@opencode-ai/plugin` from the OpenCode monorepo source. Its
    # package.json `exports` maps "." to `./src/index.ts`, so `bun build`
    # compiles the TypeScript directly. `@opencode-ai/sdk` is imported as
    # types only there and is erased during transpilation.
    mkdir -p node_modules/@opencode-ai
    cp -r --no-preserve=mode "${inputs.opencode}/packages/plugin" node_modules/@opencode-ai/plugin

    # Vendor zod from source. The upstream repo package.json points at built
    # `dist` artifacts that do not exist in a source checkout, so replace it
    # with a minimal manifest whose entry is the TS source (`src/index.ts`,
    # which only uses relative imports).
    mkdir -p node_modules/zod
    cp -r --no-preserve=mode "$zodSrc/packages/zod/." node_modules/zod/
    cat > node_modules/zod/package.json <<EOF
    {
      "name": "zod",
      "version": "4.1.8",
      "type": "module",
      "main": "src/index.ts",
      "module": "src/index.ts"
    }
    EOF

    # OpenCode's runtime is Bun; bundle everything except node builtins.
    bun build src/index.ts --outdir dist --target bun
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/dist $out/share/skills
    cp dist/index.js $out/dist/index.js
    cp -r examples/skills/ssh-remote-dev $out/share/skills/ssh-remote-dev
    cp package.json $out/package.json
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode plugin for persistent SSH sessions with shell state persistence";
    homepage = "https://github.com/PedroKlein/opencode-ssh-session";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
  };
})
