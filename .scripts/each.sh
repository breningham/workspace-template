#!/bin/bash
# Run a command in every checked-out repo / worktree declared in repos.yaml.
# Continues past failures and reports a non-zero exit per repo.
#
#   mise run each -- git status -s
#   mise run each -- git fetch --all
#   mise run each -- npm run lint
set -uo pipefail

YAML_FILE="$(pwd)/repos.yaml"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ repos.yaml not found. Run this from the workspace root."
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "❌ Usage: mise run each -- <command>"
    exit 1
fi

# Emit every existing checked-out path (worktree repos expand to each worktree).
paths() {
    yq -o=j -I=0 '.repos[]' "$YAML_FILE" | while read -r repo; do
        NAME=$(echo "$repo" | yq '.name')
        STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')
        if [ "$STRATEGY" == "worktree" ]; then
            yq -o=j -I=0 '.worktrees[]' <<< "$repo" 2>/dev/null | while read -r wt; do
                BRANCH=$(echo "$wt" | tr -d '"')
                P="$NAME/$BRANCH"
                [ -d "$P" ] && echo "$P"
            done
        else
            [ -d "$NAME" ] && echo "$NAME"
        fi
    done
}

rc=0
while read -r P; do
    [ -z "$P" ] && continue
    echo "━━━━━━ $P ━━━━━━"
    ( cd "$P" && "$@" ) || { code=$?; echo "  ⚠️ exited $code"; rc=1; }
done < <(paths)

exit "$rc"
