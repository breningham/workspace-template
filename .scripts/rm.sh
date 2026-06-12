#!/bin/bash
# Remove a repo from repos.yaml and delete its checkout.
#
#   mise run rm <name>
#   mise run rm <name> --yes          # no confirmation prompt
#   mise run rm <name> --keep-files   # drop the repos.yaml entry only
set -euo pipefail

YAML_FILE="$(pwd)/repos.yaml"
BARE_DIR="$(pwd)/.bare-repos"
[ -f "$YAML_FILE" ] || { echo "❌ repos.yaml not found. Run from the workspace root."; exit 1; }

NAME="" ; ASSUME_YES=0 ; KEEP_FILES=0

# `mise run rm` passes usage-parsed values as usage_* env vars (not $@); seed
# from those, then let any positional args below override (direct invocation).
[ -n "${usage_name:-}" ]            && NAME="$usage_name"
[ "${usage_yes:-}" = "true" ]       && ASSUME_YES=1
[ "${usage_keep_files:-}" = "true" ] && KEEP_FILES=1

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)     ASSUME_YES=1; shift;;
        --keep-files) KEEP_FILES=1; shift;;
        -h|--help)    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
        -*)           echo "❌ Unknown flag: $1"; exit 1;;
        *)            [ -z "$NAME" ] && NAME="$1" || { echo "❌ Unexpected arg: $1"; exit 1; }; shift;;
    esac
done

[ -n "$NAME" ] || { echo "❌ Usage: mise run rm <repo-name> [--yes] [--keep-files]"; exit 1; }

if ! NAME="$NAME" yq -e '.repos[] | select(.name == strenv(NAME)) | .name' "$YAML_FILE" >/dev/null 2>&1; then
    echo "❌ '$NAME' is not in repos.yaml."; exit 1
fi

STRATEGY=$(NAME="$NAME" yq '.repos[] | select(.name == strenv(NAME)) | .strategy // "clone"' "$YAML_FILE")

if [ "$KEEP_FILES" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; then
    read -r -p "Remove '$NAME' ($STRATEGY) and delete its files? [y/N]: " reply </dev/tty || true
    case "$reply" in y|Y|yes|Yes) ;; *) echo "Aborted."; exit 0;; esac
fi

# Drop it from the code graph (best-effort).
if command -v code-review-graph >/dev/null 2>&1; then
    code-review-graph unregister "$NAME" >/dev/null 2>&1 || true
    code-review-graph daemon remove "$NAME" >/dev/null 2>&1 || true
fi

if [ "$KEEP_FILES" -eq 0 ]; then
    if [ "$STRATEGY" = "worktree" ]; then
        BARE="$BARE_DIR/$NAME.git"
        if [ -d "$NAME" ]; then
            for wt in "$NAME"/*/; do
                [ -d "$wt" ] || continue
                [ -d "$BARE" ] && git --git-dir="$BARE" worktree remove "${wt%/}" --force 2>/dev/null || true
            done
        fi
        rm -rf "$NAME" "$BARE"
        echo "🗑️  Removed worktrees + bare repo for '$NAME'."
    else
        rm -rf "$NAME"
        echo "🗑️  Removed '$NAME'."
    fi
fi

NAME="$NAME" yq -i 'del(.repos[] | select(.name == strenv(NAME)))' "$YAML_FILE"
echo "✅ Removed '$NAME' from repos.yaml."
