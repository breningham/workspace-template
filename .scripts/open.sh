#!/bin/bash
YAML_FILE="repos.yaml"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ repos.yaml not found. Run 'mise run setup' first."
    exit 1
fi

VALID_PATHS=()

while read -r PATH_ENTRY; do
    [ -z "$PATH_ENTRY" ] && continue
    if [ -d "$PATH_ENTRY" ]; then
        VALID_PATHS+=("$PATH_ENTRY")
    fi
done < <(
    yq '.repos[] | select(.strategy == "worktree") | .name + "/" + .worktrees[]' "$YAML_FILE"
    yq '.repos[] | select(.strategy != "worktree") | .name' "$YAML_FILE"
)

if [ ${#VALID_PATHS[@]} -eq 0 ]; then
    echo "⚠️ No cloned repositories found. Run 'mise run setup' to bootstrap your workspace."
    exit 1
fi

# Launch Zed with all active paths simultaneously
zed "${VALID_PATHS[@]}"
