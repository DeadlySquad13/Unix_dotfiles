{
  lib,
  fetchPypi,
  python3Packages,
  # build-system
  # hatchling,
  # dependencies
  # attrs,
  # pluggy,
  # py,
  # setuptools,
  # six,
}:
python3Packages.buildPythonApplication rec {
  pname = "shelloracle";

  version = "1.9.0";

  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-O41NAM9774uyFAHrZLGt40/SQNri55+b+FBejgzvyZ0=";
  };

  nativeBuildInputs = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = with python3Packages; [
    click
    # TODO: Needs to be packaged too.
    # dspy
    google-generativeai
    httpx
    openai
    prompt-toolkit
    tomlkit
    yaspin
  ];

  meta = with lib; {
    description = "Shelloracle";
    mainProgram = "shor";
    homepage = "https://github.com/djcopley/ShellOracle/tree/main";
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.gpl2Plus;
    maintainers = [maintainers.winpat];
  };
}
