{
  channels,
  inputs,
  lib,
  ...
}: final: prev: rec {
  python3 = prev.python3.override {
    packageOverrides = finalPackages: prevPackages: {
      invoke-v3 = prevPackages.invoke.overridePythonAttrs (old: rec {
        format = "pyproject";
        version = "3.0.3";
        src = prevPackages.fetchPypi {
          inherit version;
          inherit (old) pname;
          hash = "sha256-Q3tqYiIjgkOAv7TmT2EnEaa2SMeV9WXvyGJa9m+1fww=";
        };

        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ [
            finalPackages.setuptools
          ];
      });
    };
  };

  python3Packages = python3.pkgs;
}
