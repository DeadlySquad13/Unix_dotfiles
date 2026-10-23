# Custom tmux-harpoon package pinned to a revision *after* the v0.4.0 tag
# currently packaged in nixpkgs (`pkgs.tmuxPlugins.harpoon`): the extra commit
# makes switching honour a configured `base-index`/`pane-base-index`.
#
# It is consumed as a regular tmux plugin from
# `modules/home/apps/cli-utility/tmux/default.nix` through
# `programs.tmux.plugins`. Home Manager `run-shell`s the derivation's `rtp`
# and asserts that its `pname` starts with "tmuxplugin", so this must remain a
# `tmuxPlugins.mkTmuxPlugin` derivation (not a `buildEnv` wrapper).
#
# On top of the raw plugin this also:
#   * exposes the wrapped `harpoon` CLI as `$out/bin/harpoon`, so the manual
#     keybindings in `.../tmux/harpoon.conf` (`run 'harpoon …'`) resolve; and
#   * makes `harpoon.tmux` set `@harpoon_loaded`, a marker the tmux config uses
#     to source those bindings only when the plugin actually ran.
{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  tmuxPlugins,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  ncurses,
  tmux,
  util-linux,
  fzf,
  ...
}:
tmuxPlugins.mkTmuxPlugin rec {
  pluginName = "harpoon";
  version = "0-unstable-2025-07-08";
  rtpFilePath = "harpoon.tmux";

  src = fetchFromGitHub {
    owner = "Chaitanyabsprip";
    repo = "tmux-harpoon";
    rev = "fad397d42f04c31874fb7593fb7046d1f8d14864";
    hash = "sha256-eqzf3hEaliF1t7zwZlj1YDGvn0jKdbBTgy5PoOPVMEU=";
  };

  nativeBuildInputs = [makeWrapper];

  # `harpoon.tmux` shells out to the bundled `harpoon` script, which in turn
  # uses all of these tools. Wrap it so the plugin works no matter what PATH
  # the tmux server was started with (NixOS does not expose them all).
  postInstall = ''
    # `harpoon.tmux` and the bundled `harpoon` script ship with `/usr/bin/env
    # bash` and `/bin/sh` shebangs. `fixupPhase`'s `patchShebangs` leaves them
    # alone with `strictDeps = true` (its `--host` lookup misses bash), so pin
    # the shell explicitly and then wrap the script with its runtime tools.
    substituteInPlace $target/harpoon.tmux \
      --replace-fail '#!/usr/bin/env bash' '#!${stdenv.shell}'
    substituteInPlace $target/harpoon \
      --replace-fail '#!/bin/sh' '#!${stdenv.shell}'
    chmod +x $target/harpoon

    wrapProgram $target/harpoon \
      --prefix PATH : ${
      lib.makeBinPath [
        coreutils
        gawk
        gnugrep
        gnused
        ncurses
        tmux
        util-linux
        fzf
      ]
    }

    # Expose the wrapped CLI on the profile so `harpoon …` keybindings work.
    mkdir -p $out/bin
    ln -s $target/harpoon $out/bin/harpoon

    # Marker read by the tmux config (`if-shell -F "#{==:#{@harpoon_loaded},1}"`)
    # to gate the manual bindings. `run-shell` is synchronous, so it is set by
    # the time the config line after the plugin's `run-shell` is executed.
    echo 'tmux set -g @harpoon_loaded 1' >> $target/harpoon.tmux
  '';

  meta = with lib; {
    homepage = "https://github.com/Chaitanyabsprip/tmux-harpoon";
    description = "Tool to bookmark tmux sessions, supporting auto-create for sessions";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
