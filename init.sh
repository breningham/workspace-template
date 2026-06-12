#!/bin/bash
# One-shot initializer: turn a clone of this template into a fresh workspace.
# Run once, immediately after cloning. It self-destructs at the end.
set -euo pipefail

echo "Converting template to usable workspace..."

# 1. Activate the .gitignore.
if [ -f .gitignore.example ]; then
    mv .gitignore.example .gitignore
    echo "✅ .gitignore configured."
else
    echo "⚠️ .gitignore.example not found (already initialized?)."
fi

# 2. Point the code-review-graph MCP server at this workspace.
#    .opencode.json ships with a placeholder cwd; bake in the absolute path.
if [ -f .opencode.json ]; then
    if command -v sed >/dev/null 2>&1; then
        sed -i.bak "s#__WORKSPACE_DIR__#$(pwd)#g" .opencode.json && rm -f .opencode.json.bak
        echo "✅ .opencode.json pointed at $(pwd)."
    fi
fi

# 3. The agent-instruction symlinks (CLAUDE.md, GEMINI.md,
#    .github/copilot-instructions.md → AGENTS.md) are committed in the template,
#    so there's nothing to generate here — just edit AGENTS.md for your workspace.

# 4. Reset Git history for the new project.
if [ -d .git ]; then
    rm -rf .git
    git init -q
    echo "✅ Initialized fresh Git repository."
fi

# 5. Self-destruct.
echo "✅ Initialization complete."
echo "ℹ️  Next: edit repos.yaml, then run 'mise run setup' to bootstrap your repos."
rm -- "$0"
