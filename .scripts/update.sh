#!/bin/bash
# Pull latest for every checked-out repo / worktree declared in repos.yaml.
# Fast-forward only, so local work is never clobbered.
#
#   mise run update            Update everything
#   mise run update backend    Only repos tagged 'backend'
set -uo pipefail

YAML_FILE="$(pwd)/repos.yaml"
BARE_DIR="$(pwd)/.bare-repos"
TARGET_TAG="${1:-}"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ repos.yaml not found. Run this from the workspace root."
    exit 1
fi

while read -r repo; do
    [ -z "$repo" ] && continue
    NAME=$(echo "$repo" | yq '.name')
    STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')
    TAGS=$(echo "$repo" | yq '.tags[]' 2>/dev/null)

    if [ -n "$TARGET_TAG" ] && ! echo "$TAGS" | grep -q "^$TARGET_TAG$"; then
        continue
    fi

    if [ "$STRATEGY" == "worktree" ]; then
        BARE="$BARE_DIR/$NAME.git"
        [ -d "$BARE" ] && git --git-dir="$BARE" fetch --all --prune --quiet
        yq -o=j -I=0 '.worktrees[]' <<< "$repo" 2>/dev/null | while read -r wt; do
            BRANCH=$(echo "$wt" | tr -d '"')
            P="$NAME/$BRANCH"
            [ -d "$P" ] || continue
            echo "🔄 $P"
            git -C "$P" pull --ff-only --quiet || echo "  ⚠️ pull failed (not fast-forward?) — $P"
        done
    else
        [ -d "$NAME" ] || continue
        echo "🔄 $NAME"
        git -C "$NAME" pull --ff-only --quiet || echo "  ⚠️ pull failed (not fast-forward?) — $NAME"
    fi
done < <(yq -o=j -I=0 '.repos[]' "$YAML_FILE")

echo "✅ Update complete."
echo "ℹ️  If the watch daemon isn't running, refresh graphs with: mise run graph build"
