#!/bin/bash
YAML_FILE="$(pwd)/repos.yaml"
BARE_DIR="$(pwd)/.bare-repos"
# mise passes the [tag] arg as usage_tag; fall back to $1 for direct invocation.
TARGET_TAG="${usage_tag:-${1:-}}"

if [ ! -f "$YAML_FILE" ]; then
    echo "❌ repos.yaml not found."
    exit 1
fi

mkdir -p "$BARE_DIR"
echo "Bootstrapping workspace..."

while read -r repo; do
    [ -z "$repo" ] && continue
    NAME=$(echo "$repo" | yq '.name')
    URL=$(echo "$repo" | yq '.url')
    STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')
    TAGS=$(echo "$repo" | yq '.tags[]')

    if [ -n "$TARGET_TAG" ] && ! echo "$TAGS" | grep -q "^$TARGET_TAG$"; then
        continue
    fi

    echo "📦 Processing $NAME ($STRATEGY)..."

    if [ "$STRATEGY" == "worktree" ]; then
        BARE_REPO_PATH="$BARE_DIR/$NAME.git"
        if [ ! -d "$BARE_REPO_PATH" ]; then
            git clone --bare "$URL" "$BARE_REPO_PATH"
            git --git-dir="$BARE_REPO_PATH" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        fi
        mkdir -p "$NAME"

        yq -o=j -I=0 '.worktrees[]' <<< "$repo" | while read -r wt; do
            BRANCH=$(echo "$wt" | tr -d '"')
            WORKTREE_PATH="$NAME/$BRANCH"
            if [ ! -d "$WORKTREE_PATH" ]; then
                git --git-dir="$BARE_REPO_PATH" --work-tree="$WORKTREE_PATH" worktree add "$WORKTREE_PATH" "$BRANCH"

                # Execute shared hook
                if ! ./.scripts/_run-commands.sh "$NAME" "$WORKTREE_PATH" "$YAML_FILE"; then
                    exit 1
                fi
            else
                echo "   ✅ Worktree $BRANCH already exists."
            fi
        done
    else
        BRANCH=$(echo "$repo" | yq '.branch // "main"')
        if [ ! -d "$NAME" ]; then
            git clone -b "$BRANCH" "$URL" "$NAME"

            # Execute shared hook
            if ! ./.scripts/_run-commands.sh "$NAME" "$NAME" "$YAML_FILE"; then
                exit 1
            fi
        else
            echo "   ✅ $NAME already exists."
        fi
    fi
done < <(yq -o=j -I=0 '.repos[]' "$YAML_FILE")

echo "✅ Workspace bootstrap complete."
