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
| `mise run open` | Launch the multi-root workspace in Zed. |
| `mise run wt add\|rm\|prune` | Manage `strategy: worktree` worktrees. |
| `mise run update` | `git pull --ff-only` every repo/worktree (optional tag filter). |
| `mise run each -- <cmd>` | Run a command in every checked-out repo/worktree. |
| `mise run graph build\|refresh\|status\|daemon` | Manage the cross-repo code graph. |
| `mise run format` | Prettier across the shell repo. |

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
