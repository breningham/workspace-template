# Workspace Meta-Repository Template

A centralized, LLM-friendly workspace manager for polyrepo environments. This template bootstraps independent Git repositories and bare-repo worktrees from a single configuration file, entirely avoiding the overhead of Git submodules.

It isolates global documentation and LLM context from production codebases, and automatically generates a unified workspace launcher for Zed.

## Prerequisites

Ensure the following are installed on your system:
- **Git**
- **[yq](https://github.com/mikefarah/yq)** (for parsing the YAML configuration)
- **[Zed](https://zed.dev/)** (for the auto-generated multi-root workspace launcher)

## Getting Started

1. Clone this repository (do not use `--recursive`).
2. Define your desired projects in `repos.yaml`.
3. Run the bootstrap script:
```bash
   ./.scripts/setup.sh
   ```
4. Launch your unified workspace:
```bash
   ./open.sh
   ```

## Configuration (`repos.yaml`)

The `repos.yaml` file acts as the source of truth for your local environment. It supports standard repository clones and bare-repo worktrees for larger monorepos.

### Schema Options

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | The local directory name (useful for stripping repetitive prefixes). |
| `url` | String | The remote Git URL. |
| `strategy` | String | (Optional) `clone` (default) or `worktree`. |
| `branch` | String | (Optional) Target branch for standard clones. Defaults to `main`. |
| `worktrees` | Array | (Optional) List of branches to check out into isolated folders when using the `worktree` strategy. |
| `tags` | Array | (Optional) Grouping labels to selectively bootstrap parts of the architecture. |
| `description`| String | (Optional) Multi-line project context specifically formatted for local LLMs. |

### Example

```yaml
repos:
  - name: document-service
    url: git@github.com:Organization/click-document-service.git
    branch: main
    tags: 
      - backend

  - name: click-apps
    url: git@github.com:Organization/click-apps.git
    strategy: worktree
    worktrees:
      - main
      - develop
    tags: 
      - frontend
```

## Advanced Usage: Tag Filtering

If your workspace grows large, you can bootstrap a specific subset of repositories by passing a tag to the setup script. For example, to only pull down projects tagged with `backend`:

```bash
./.scripts/setup.sh backend
```

## Directory Structure

To prevent Git from tracking the cloned services, the `.gitignore` is configured to ignore all directories at the root level except `.scripts/` and hidden files like `.bare-repos/`. The parent repository serves purely as a structural shell.
