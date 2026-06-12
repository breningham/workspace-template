# Agent operating context — workspace shell

> Canonical agent instructions for this repo. `CLAUDE.md`, `GEMINI.md` and
> `.github/copilot-instructions.md` are symlinks to this file — edit it here.

## What this repo is

This is **not** an application. It's a thin shell that bootstraps and manages a
polyrepo workspace of independent repositories. Each subdirectory is its own Git
repo with its own deps, lint, and deploy pipeline — there is **no top-level
build/test/lint**. Always `cd` into a specific repo before running its commands,
and read that repo's own `CLAUDE.md`/`AGENTS.md`/`README.md` (they take
precedence inside that repo).

The cloned repos are git-ignored; this shell only tracks `repos.yaml`,
`mise.toml`, `.scripts/`, and the docs.

## Operational rules

1. **Never** run scripts in `.scripts/` directly — always use the mapped mise task.
2. **Never** touch `.bare-repos/` (git's internal worktree storage).
3. To add/change a repo: edit `repos.yaml`, then run `mise run setup` (clones are
   the user's to make, not the agent's).
4. Keep cross-project notes in this shell, isolated from the production repos.

## How the tooling fits together

Everything is driven by **`repos.yaml`** (the source of truth) through **mise
tasks** that wrap the scripts in `.scripts/`.

- `repos.yaml` declares every repo, how to obtain it, and per-repo `setup_commands`.
- `mise.toml` pins the toolchain and exposes the tasks below.

### mise tasks (run from this directory)

| Task | What it does |
|------|--------------|
| `mise run setup` | Bootstrap every repo/worktree in `repos.yaml` (idempotent — skips existing). Append a tag for a subset, e.g. `mise run setup -- backend`. |
| `mise run open` | Launch the multi-root workspace in Zed for all cloned repos/worktrees. |
| `mise run wt add <repo> <branch>` | Add a worktree (only for `strategy: worktree` repos). Resolves local → remote → new-off-`main`, then runs that repo's `setup_commands`. |
| `mise run wt rm <repo> <branch>` | Remove a worktree and its local branch. |
| `mise run wt prune` | Clean up stale/orphaned worktree dirs. |
| `mise run update` | `git pull --ff-only` every repo/worktree (optional tag filter: `mise run update backend`). |
| `mise run each -- <cmd>` | Run a command in every checked-out repo/worktree (e.g. `mise run each -- git status -s`). |
| `mise run graph <build\|refresh\|status\|daemon>` | Manage the code-review-graph index (see below). |
| `mise run format` | `prettier --write .` across the shell repo. |

### `repos.yaml` entry schema

| Field | Notes |
|------|-------|
| `name` | Local directory name. |
| `url` | Remote git URL (SSH). |
| `strategy` | `clone` (default) or `worktree`. |
| `branch` | For `clone` — defaults to `main`. |
| `worktrees` | For `worktree` — list of branches checked out into `name/<branch>/`. |
| `tags` | Grouping labels for `mise run setup -- <tag>`. |
| `setup_commands` | Array run inside the repo after checkout (e.g. `mise use node@24`, `npm i`). `setup_command` (singular string) also supported. |
| `description` | Multi-line context written for LLMs — keep it useful. |

A top-level `global.setup_commands` block runs in every repo after checkout,
before that repo's own `setup_commands`.

## Cross-repo code graph (code-review-graph)

A structural graph of the whole workspace is maintained centrally so agents can
ask callers/callees/impact questions across repos.

- **How it's wired:** each repo's `setup_commands` (plus the `global` block in
  `repos.yaml`) run `code-review-graph register . --alias <name>` + `build` on
  checkout, so a fresh `mise run setup` indexes everything. `mise run graph build`
  backfills/rebuilds existing checkouts.
- **Where it lives:** each repo's graph is a self-gitignored
  `<repo>/.code-review-graph/graph.db`. A central registry at
  `~/.code-review-graph/registry.json` ties them together for cross-repo queries.
- **Keeping it fresh:** `mise run graph daemon start` watches all registered
  repos. The daemon keeps its *own* watch config, separate from the cross-repo
  registry, so `graph daemon start`/`restart` first syncs the watch list from
  `repos.yaml` via `daemon add` — otherwise the daemon boots watching 0 repos
  even when `graph status` shows a full registry. (Storage must stay at the
  default in-repo path — the daemon hardcodes it, so don't redirect it with
  `--data-dir`.)
- **Querying:** the `code-review-graph` MCP server (`.opencode.json`) exposes
  cross-repo tools (`cross_repo_search`, `list_repos`, `query_graph`,
  `semantic_search_nodes`, `get_impact_radius`). Single-repo tools operate on the
  *current* repo, so run them from inside a service dir, not the meta-root.

## Committing

- Follow conventions set by each individual project.
- Do **not** add yourself as a co-author on the commit or PR body.
