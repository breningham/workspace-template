#!/bin/bash

echo "Converting template to usable workspace..."

# 1. Setup .gitignore
if [ -f .gitignore.example ]; then
    mv .gitignore.example .gitignore
    echo "✅ .gitignore configured."
else
    echo "⚠️ .gitignore.example not found."
fi

# 2. Generate agents.md for LLM context
if [ ! -f agents.md ]; then
    cat << 'EOF' > agents.md
# LLM Agent Operating Context

## Workspace Structure
This is a meta-repository managing multiple independent projects.
- **Architecture:** Polyrepo (no Git submodules).
- **Configuration:** `repos.yaml` defines the active services and branches.
- **Editor:** Zed (multi-root workspace launched via `./open.sh`).

## Operational Rules
1. **Never** modify files inside the hidden `.bare-repos/` directory.
2. If a new repository needs to be added, update `repos.yaml` and instruct the user to run `./.scripts/setup.sh`.
3. Keep cross-project documentation and global architecture notes in this root directory, isolated from the service codebases.
EOF
    echo "✅ agents.md generated."
fi

# 3. Reset Git history for the new project
if [ -d .git ]; then
    rm -rf .git
    git init
    echo "✅ Initialized fresh Git repository."
fi

# 4. Self-destruct
echo "✅ Initialization complete."
rm -- "$0"
