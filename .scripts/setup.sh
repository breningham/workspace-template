#!/bin/bash

YAML_FILE="repos.yaml"
BARE_DIR=".bare-repos"

mkdir -p "$BARE_DIR"

echo "Bootstrapping workspace..."

yq -o=j -I=0 '.repos[]' "$YAML_FILE" | while read -r repo; do
    NAME=$(echo "$repo" | yq '.name')
    URL=$(echo "$repo" | yq '.url')
    STRATEGY=$(echo "$repo" | yq '.strategy // "clone"')

    echo "📦 Processing $NAME ($STRATEGY)..."

    if [ "$STRATEGY" == "worktree" ]; then
        BARE_REPO_PATH="$BARE_DIR/$NAME.git"
        
        # 1. Clone bare repo if it doesn't exist
        if [ ! -d "$BARE_REPO_PATH" ]; then
            git clone --bare "$URL" "$BARE_REPO_PATH"
        fi

        # 2. Create the parent directory for the worktrees
        mkdir -p "$NAME"

        # 3. Add the worktrees
        yq -o=j -I=0 '.worktrees[]' <<< "$repo" | while read -r wt; do
            BRANCH=$(echo "$wt" | tr -d '"')
            WORKTREE_PATH="$NAME/$BRANCH"
            
            if [ ! -d "$WORKTREE_PATH" ]; then
                # Create the worktree linked to the bare repo
                git --git-dir="$BARE_REPO_PATH" --work-tree="$WORKTREE_PATH" worktree add "$WORKTREE_PATH" "$BRANCH"
            else
                echo "   ✅ Worktree $BRANCH already exists."
            fi
        done

    else
        # Standard clone logic
        BRANCH=$(echo "$repo" | yq '.branch // "main"')
        if [ ! -d "$NAME" ]; then
            git clone -b "$BRANCH" "$URL" "$NAME"
        else
            echo "   ✅ $NAME already exists."
        fi
    fi
done

echo "Done!"
