# TODO: Refactor to match Snowfall lib criteria
{
  description = "Flake with bun support";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in rec {
        flakedPkgs = pkgs;

        # enables use of `nix shell`
        devShell = pkgs.mkShell {
          # add things you want in your shell here
          buildInputs = with pkgs; [
            bun
          ];

          # FIX: Currently at nix-darwin bash completions are incomplete.
          # Reference: https://github.com/NixOS/nixpkgs/blob/1766437c5509f444c1b15331e82b8b6a9b967000/pkgs/by-name/bu/bun/package.nix#L56-L72
          # It's still better than nothing so adding this by hand.
          # TODO: Use bash utils for logging.
          shellHook = ''
            # INFO: See this [discussion in direnv](zotero://select/library/items/@/NotAbleAuto). To provide
            # shell cross-compatibility, direnv doesn't export functions. So we
            # can't source compeltions directly. Instead we just define where
            # they can be accessed.
            # More info about common paths in completion:
            # [scop/bash-completion](zotero://select/library/items/@/Skytta/ScopBashcompletion.2026)
            USER_XDG_DATA_DIR="$HOME/.local/share"
            export XDG_DATA_DIRS="$XDG_DATA_DIRS:$USER_XDG_DATA_DIR"

            USER_BASH_COMPLETIONS_PATH="$USER_XDG_DATA_DIR/bash-completion"
            # The naming is important: file should be in `completions` and have
            # `.bash` postfix for bash completions.
            BUN_COMPLETIONS_PATH="''${XDG_DATA_HOME:-$USER_BASH_COMPLETIONS_PATH}/completions/bun.bash"

            if [[ ! -f $BUN_COMPLETIONS_PATH ]]; then
              echo "No bun completions file found, generating..."
              ${pkgs.bun}/bin/bun completions > $BUN_COMPLETIONS_PATH
              sed --in-place "s/local re_prev_script=/return; local re_prev_script=/" $BUN_COMPLETIONS_PATH
            fi
          '';
        };
      }
    );
}
