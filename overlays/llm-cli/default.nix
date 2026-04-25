{
  channels,
  inputs,
  ...
}: final: prev: (
  let
    inherit (inputs.nixpkgs.legacyPackages.${prev.system}) llm;
  in {
    ds-omega-llm-cli = llm.withPlugins {
      # Use LLM to generate and execute commands in your shell <https://github.com/simonw/llm-cmd>
      llm-cmd = true;

      # Ask questions of LLM documentation using LLM <https://github.com/simonw/llm-docs>
      llm-docs = true;

      # Debug plugin for LLM <https://github.com/simonw/llm-echo>
      llm-echo = true;

      # Load GitHub repository contents as LLM fragments <https://github.com/simonw/llm-fragments-github>
      llm-fragments-github = true;

      # LLM fragments plugin for PyPI packages metadata <https://github.com/samueldg/llm-fragments-pypi>
      llm-fragments-pypi = true;

      # Run URLs through the Jina Reader API <https://github.com/simonw/llm-fragments-reader>
      llm-fragments-reader = true;

      # LLM fragment loader for Python symbols <https://github.com/simonw/llm-fragments-symbex>
      llm-fragments-symbex = true;

      # AI-powered Git commands for the LLM CLI tool <https://github.com/OttoAllmendinger/llm-git>
      llm-git = true;

      # LLM plugin for pulling content from Hacker News <https://github.com/simonw/llm-hacker-news>
      llm-hacker-news = true;

      # Write and execute jq programs with the help of LLM <https://github.com/simonw/llm-jq>
      llm-jq = true;

      # LLM plugin for interacting with llama-server models <https://github.com/simonw/llm-llama-server>
      # llm-llama-server = true;

      # LLM plugin providing access to Ollama models using HTTP API <https://github.com/taketwo/llm-ollama>
      llm-ollama = true;

      # LLM plugin for models hosted by OpenRouter <https://github.com/simonw/llm-openrouter>
      # llm-openrouter = true;

      # LLM fragment plugin to load a PDF as a sequence of images <https://github.com/simonw/llm-pdf-to-images>
      llm-pdf-to-images = true;

      # LLM plugin for embeddings using sentence-transformers <https://github.com/simonw/llm-sentence-transformers>
      # llm-sentence-transformers = true;

      # Load LLM templates from Fabric <https://github.com/simonw/llm-templates-fabric>
      # llm-templates-fabric = true;

      # Load LLM templates from GitHub repositories <https://github.com/simonw/llm-templates-github>
      # llm-templates-github = true;

      # Expose Datasette instances to LLM as a tool <https://github.com/simonw/llm-tools-datasette>
      llm-tools-datasette = true;

      # JavaScript execution as a tool for LLM <https://github.com/simonw/llm-tools-quickjs>
      # llm-tools-quickjs = true;

      # Make simple_eval available as an LLM tool <https://github.com/simonw/llm-tools-simpleeval>
      # https://pypi.org/project/simpleeval/
      llm-tools-simpleeval = true;

      # LLM tools for running queries against SQLite <https://github.com/simonw/llm-tools-sqlite>
      llm-tools-sqlite = true;

      # LLM plugin to turn a video into individual frames <https://github.com/simonw/llm-video-frames>
      # llm-video-frames = true;
    };
  }
)
