#!/bin/bash
# One-screen overview of the workspace: branch, working-tree state, sync vs
# upstream, and whether each repo is indexed in the code graph. Also flags drift
# (configured-but-missing, and checked-out-but-unconfigured).
#
#   mise run status
set -uo pipefail

YAML_FILE="$(pwd)/repos.yaml"
REGISTRY="$HOME/.code-review-graph/registry.json"
[ -f "$YAML_FILE" ] || { echo "❌ repos.yaml not found. Run from the workspace root."; exit 1; }

graph_indexed() { # $1 = absolute repo path
    [ -f "$REGISTRY" ] || return 1
    P="$1" yq -p=json -e '.repos[] | select(.path == strenv(P))' "$REGISTRY" >/dev/null 2>&1
}

sync_str() { # $1 = repo path → ↑ahead ↓behind, ✓ in sync, or — no upstream
    local lr behind ahead s=""
    lr=$(git -C "$1" rev-list --count --left-right '@{u}...HEAD' 2>/dev/null) || { printf '—'; return; }
    behind=${lr%%	*}; ahead=${lr##*	}
    [ "${ahead:-0}" -gt 0 ] && s="↑$ahead"
    [ "${behind:-0}" -gt 0 ] && s="${s:+$s }↓$behind"
    printf '%s' "${s:-✓}"
}

row() { printf '  %-34s %-22s %-7s %-8s %s\n' "$1" "$2" "$3" "$4" "$5"; }

# Collect configured paths so we can diff against what's on disk.
CONFIGURED=$(mktemp)

printf '\n'
row "REPO" "BRANCH" "STATE" "SYNC" "GRAPH"
printf '  %s\n' "----------------------------------------------------------------------"

while read -r repo; do
    [ -z "$repo" ] && continue
    NAME=$(echo "$repo" | yq '.name')
    STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')

    if [ "$STRATEGY" = "worktree" ]; then
        echo "$repo" | yq -o=j -I=0 '.worktrees[]' 2>/dev/null | while read -r wt; do
            BRANCH=$(echo "$wt" | tr -d '"'); P="$NAME/$BRANCH"
            echo "$(pwd)/$P" >> "$CONFIGURED"
            if [ -d "$P" ]; then
                cur=$(git -C "$P" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
                state=$([ -z "$(git -C "$P" status --porcelain 2>/dev/null)" ] && echo clean || echo "dirty")
                g=$(graph_indexed "$(pwd)/$P" && echo "✓" || echo "—")
                row "$P" "$cur" "$state" "$(sync_str "$P")" "$g"
            else
                row "$P" "—" "MISSING" "—" "—"
            fi
        done
    else
        echo "$(pwd)/$NAME" >> "$CONFIGURED"
        if [ -d "$NAME" ]; then
            cur=$(git -C "$NAME" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
            state=$([ -z "$(git -C "$NAME" status --porcelain 2>/dev/null)" ] && echo clean || echo "dirty")
            g=$(graph_indexed "$(pwd)/$NAME" && echo "✓" || echo "—")
            row "$NAME" "$cur" "$state" "$(sync_str "$NAME")" "$g"
        else
            row "$NAME" "—" "MISSING" "—" "—"
        fi
    fi
done < <(yq -o=j -I=0 '.repos[]' "$YAML_FILE")

# Drift: top-level git checkouts not described by repos.yaml.
UNTRACKED=""
for d in */; do
    d=${d%/}
    case "$d" in .scripts|.bare-repos|.github) continue;; esac
    [ -d "$d/.git" ] || [ -f "$d/.git" ] || continue
    grep -qx "$(pwd)/$d" "$CONFIGURED" 2>/dev/null && continue
    UNTRACKED="${UNTRACKED}  ⚠️  $d (on disk, not in repos.yaml)\n"
done
rm -f "$CONFIGURED"

if [ -n "$UNTRACKED" ]; then
    printf '\nDrift:\n'
    printf '%b' "$UNTRACKED"
fi
printf '\n'
