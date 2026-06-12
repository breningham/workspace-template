# Workspace Meta-Repository Template

A centralized, LLM-friendly workspace manager for polyrepo environments. This
template bootstraps independent Git repositories and bare-repo worktrees from a
single configuration file, entirely avoiding the overhead of Git submodules.

It isolates global documentation and LLM context from production codebases,
drives everything through [mise](https://mise.jdx.dev/) tasks, and maintains a
cross-repo code graph for structural code queries across services.

## Prerequisites

Ensure the following are installed on your system:

- **Git**
- **[mise](https://mise.jdx.dev/)** — the task runner; it provisions the rest of
  the toolchain (`yq`, `prettier`, `code-review-graph`) from `mise.toml`.
- **[Zed](https://zed.dev/)** (for the `mise run open` multi-root launcher).

## Getting Started

1. Clone this repository (do not use `--recursive`).
2. Initialize it (activates `.gitignore`, wires the MCP config, resets git
   history, then self-destructs):
   ```bash
   ./init.sh
   ```
3. Trust the toolchain and let mise install it:
   ```bash
   mise trust && mise install
   ```
4. Define your projects in `repos.yaml`.
5. Bootstrap the workspace:
   ```bash
   mise run setup
   ```
6. Launch the unified workspace:
   ```bash
   mise run open
   ```

## mise tasks

| Task | What it does |
|------|--------------|
| `mise run setup` | Bootstrap every repo/worktree in `repos.yaml` (idempotent). Tag filter: `mise run setup -- backend`. |
| `mise run add <url>` | Add a new repo to `repos.yaml` and check it out (prompts, all skippable via flags). |
| `mise run rm <name>` | Remove a repo from `repos.yaml` and delete its checkout. |
| `mise run status` | Branch / dirty / sync / graph status for every repo, plus drift. |
| `mise run open` | Launch the multi-root workspace in Zed. |
| `mise run wt add\|rm\|prune` | Manage `strategy: worktree` worktrees. |
| `mise run update` | `git pull --ff-only` every repo/worktree (optional tag filter). |
| `mise run each -- <cmd>` | Run a command in every checked-out repo/worktree. |
| `mise run graph build\|refresh\|status\|daemon` | Manage the cross-repo code graph. |
| `mise run format` | Prettier across the shell repo. |

### Adding a repo

```bash
mise run add git@github.com:ClickDealer/click-foo-service.git
# …or fully non-interactive:
mise run add <url> --name foo --defaultBranch develop \
  --description "…" --setupCommands="npm install, npm run build" --tags "backend,core"
```

It appends a valid entry to `repos.yaml` (description defaults to the repo's
GitHub description via `gh`), then clones and runs the post-checkout hook.

## Shell completions (zsh / fish)

The tasks ship [`usage`](https://usage.jdx.dev) specs, so mise can complete task
names **and** their arguments — `mise run rm <TAB>` lists repo names, `mise run
setup <TAB>` lists tags. The `usage` CLI (pinned in `mise.toml`) powers this;
`mise install` provides it.

Enable mise's completions once per shell:

```bash
# zsh — ensure the dir is on your fpath, then reload
mkdir -p ~/.config/zsh/completions
mise completion zsh > ~/.config/zsh/completions/_mise

# fish
mise completion fish > ~/.config/fish/completions/mise.fish
```

(See `mise completion --help` for bash and other shells.)

## Configuration (`repos.yaml`)

The `repos.yaml` file is the source of truth for your local environment. It
supports standard clones and bare-repo worktrees for larger monorepos.

### Schema Options

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | The local directory name. |
| `url` | String | The remote Git URL (SSH). |
| `strategy` | String | (Optional) `clone` (default) or `worktree`. |
| `branch` | String | (Optional) Target branch for standard clones. Defaults to `main`. |
| `worktrees` | Array | (Optional) Branches to check out into isolated folders under the `worktree` strategy. |
| `tags` | Array | (Optional) Grouping labels for selective bootstrap (`mise run setup -- <tag>`). |
| `setup_commands` | Array | (Optional) Commands run inside the repo after checkout. `setup_command` (string) also supported. |
| `description`| String | (Optional) Multi-line project context for local LLMs. |

A top-level `global.setup_commands` block runs in every repo after checkout
(used by default to register each repo into the code graph).

## Cross-repo code graph

`mise run graph build` registers and indexes every checked-out repo into a
central [code-review-graph](https://pypi.org/project/code-review-graph/) registry
(`~/.code-review-graph/registry.json`), and `mise run graph daemon start` keeps
the indexes fresh on file changes. The MCP server is wired in `.opencode.json`,
exposing cross-repo tools (`cross_repo_search`, `query_graph`,
`get_impact_radius`, …). Don't use the graph? Drop the `global.setup_commands`
block from `repos.yaml`, the `graph` task from `mise.toml`, and `.opencode.json`.

## Agent instructions

`AGENTS.md` is the canonical operating context for coding agents. `CLAUDE.md`,
`GEMINI.md`, and `.github/copilot-instructions.md` are symlinks to it — edit
`AGENTS.md` and every agent picks it up.

## Directory Structure

The `.gitignore` ignores all cloned service directories at the root, keeping only
`.scripts/`, `.github/`, and the tracked shell files. `.bare-repos/` (git's
worktree storage) and `.code-review-graph/` (graph indexes) are ignored too. The
parent repository serves purely as a structural shell.
