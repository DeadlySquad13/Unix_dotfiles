Project worktree root loosk like:

```bash
auto-hub$ tree -L 1
. # <- root of project with worktrees
├── 443
├── Analytics # <- worktree
├── AutoHub.git # <- worktree
├── CurrentTask # <- worktree
├── CurrentTask1 # <- worktree
├── Epic # <- worktree
├── KnowledgeBase__
├── Main -> /Users/apakalo/Projects/auto-hub/AutoHub.git # <- worktree
├── Master -> /Users/apakalo/Projects/auto-hub/AutoHub.git # <- worktree
├── Release # <- worktree
├── Review # <- worktree
# Auxiliary directories and files, here will be .local-artifacts stored and symlinked.
├── _configs
├── _http
├── _scripts -> /nix/store/xi4hsn0rdlz28ypiiqcxii352pzgvj6q-home-manager-files/Projects/--professional/Rutube__/AutoHub/_scripts
├── _utils
├── aider-backup
├── docker
├── node_modules
├── shared-scripts
└── yarn.lock

```

Main, Master and so on are not fixed names. They can be anything.
