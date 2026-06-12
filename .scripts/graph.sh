#!/bin/bash
# Drive the code-review-graph multi-repo index for the workspace.
#
#   mise run graph build    Register + build the graph for every checked-out repo
#                           in repos.yaml (idempotent — also backfills repos that
#                           were cloned before indexing was wired in).
#   mise run graph status   Show the registry + per-repo node counts.
#   mise run graph daemon … Passthrough to `code-review-graph daemon`
#                           (start|stop|restart|status|logs) — keeps every
#                           registered repo's graph fresh on file changes.
#
# Graphs live in each repo's self-gitignored .code-review-graph/graph.db (the
# child repos' tracked files are never touched). Cross-repo queries work via the
# central registry at ~/.code-review-graph/registry.json.
set -euo pipefail

YAML_FILE="$(pwd)/repos.yaml"
COMMAND="${1:-build}"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ repos.yaml not found. Run this from the workspace root."
    exit 1
fi

# Emit "<alias>\t<path>" for every checked-out repo we want indexed.
# Worktree repos are indexed on `main` only (avoid triplicating the graph).
resolve_paths() {
    yq -o=j -I=0 '.repos[]' "$YAML_FILE" | while read -r repo; do
        NAME=$(echo "$repo" | yq '.name')
        STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')
        if [ "$STRATEGY" == "worktree" ]; then
            P="$NAME/main"
        else
            P="$NAME"
        fi
        [ -d "$P" ] && printf '%s\t%s\n' "$NAME" "$(pwd)/$P"
    done
}

case "$COMMAND" in
    build|refresh)
        echo "📊 Indexing workspace into the code-review-graph registry..."
        resolve_paths | while IFS=$'\t' read -r ALIAS REPO_PATH; do
            echo "  📦 $ALIAS"
            code-review-graph register "$REPO_PATH" --alias "$ALIAS" >/dev/null
            code-review-graph build --repo "$REPO_PATH"
        done
        echo "✅ Graph build complete. Registered repos:"
        code-review-graph repos
        ;;
    status)
        echo "=== Registered repos ==="
        code-review-graph repos
        resolve_paths | while IFS=$'\t' read -r ALIAS REPO_PATH; do
            echo "--- $ALIAS ---"
            code-review-graph status --repo "$REPO_PATH" 2>&1 | grep -E '^(Nodes|Edges|Files|Languages):' || true
        done
        ;;
    daemon)
        shift
        SUB="${1:-status}"
        # The daemon keeps its own watch config, separate from the cross-repo
        # registry. Nothing else feeds it, so sync it from repos.yaml before
        # (re)starting — otherwise the daemon boots watching 0 repos even though
        # `graph status` shows a full registry. `daemon add` is idempotent.
        if [ "$SUB" == "start" ] || [ "$SUB" == "restart" ]; then
            resolve_paths | while IFS=$'\t' read -r ALIAS REPO_PATH; do
                code-review-graph daemon add "$REPO_PATH" --alias "$ALIAS" >/dev/null 2>&1 || true
            done
        fi
        code-review-graph daemon "$@"
        ;;
    *)
        echo "❌ Unknown command. Available: build, refresh, status, daemon"
        exit 1
        ;;
esac
