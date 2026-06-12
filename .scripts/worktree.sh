#!/bin/bash
YAML_FILE="repos.yaml"
BARE_DIR=".bare-repos"
COMMAND=$1

case "$COMMAND" in
    add)
            REPO=$2
            BRANCH=$3

            if [ -z "$REPO" ] || [ -z "$BRANCH" ]; then
                echo "❌ Usage: mise run wt add <repo-name> <branch-name>"
                exit 1
            fi

            BARE_REPO_PATH="$BARE_DIR/$REPO.git"
            WORKTREE_PATH="$REPO/$BRANCH"

            STRATEGY=$(yq ".repos[] | select(.name == \"$REPO\") | .strategy" "$YAML_FILE")
            if [ "$STRATEGY" != "worktree" ]; then
                echo "❌ Repo '$REPO' is not configured with the 'worktree' strategy in repos.yaml."
                exit 1
            fi

            if [ -d "$WORKTREE_PATH" ]; then
                echo "⚠️ Worktree for branch '$BRANCH' already exists at $WORKTREE_PATH"
                exit 1
            fi

            echo "🔍 Fetching latest remote state for '$REPO'..."
            # Explicitly fetch remote branches to refs/remotes/origin/ for bare repos
            git --git-dir="$BARE_REPO_PATH" fetch origin "+refs/heads/*:refs/remotes/origin/*"

            if git --git-dir="$BARE_REPO_PATH" show-ref --quiet --verify "refs/heads/$BRANCH"; then
                echo "✨ Existing local branch found. Checking out worktree for '$BRANCH'..."
                git --git-dir="$BARE_REPO_PATH" worktree add "$WORKTREE_PATH" "$BRANCH"
            elif git --git-dir="$BARE_REPO_PATH" show-ref --quiet --verify "refs/remotes/origin/$BRANCH"; then
                echo "☁️ Existing remote branch found. Checking out worktree for '$BRANCH' tracking origin..."
                git --git-dir="$BARE_REPO_PATH" worktree add "$WORKTREE_PATH" -b "$BRANCH" "origin/$BRANCH"
            else
                echo "🌱 Branch not found. Creating a new worktree tracking 'main'..."
                git --git-dir="$BARE_REPO_PATH" worktree add "$WORKTREE_PATH" -b "$BRANCH" main
            fi

            # Execute shared hook
            if ! ./.scripts/_run-commands.sh "$REPO" "$WORKTREE_PATH" "$(pwd)/$YAML_FILE"; then
                exit 1
            fi

            echo "✅ Worktree is fully provisioned."
            ;;
    rm)
        REPO=$2
        BRANCH=$3

        if [ -z "$REPO" ] || [ -z "$BRANCH" ]; then
            echo "❌ Usage: mise run wt rm <repo-name> <branch-name>"
            exit 1
        fi

        BARE_REPO_PATH="$BARE_DIR/$REPO.git"
        WORKTREE_PATH="$REPO/$BRANCH"

        if [ ! -d "$WORKTREE_PATH" ]; then
            echo "⚠️ Worktree directory not found at $WORKTREE_PATH"
            exit 1
        fi

        echo "🗑️ Removing worktree for '$BRANCH' in '$REPO'..."
        git --git-dir="$BARE_REPO_PATH" worktree remove "$WORKTREE_PATH" --force
        rm -rf "$WORKTREE_PATH" 2>/dev/null || true

        echo "🗑️ Removing local branch '$BRANCH'..."
        git --git-dir="$BARE_REPO_PATH" branch -D "$BRANCH" 2>/dev/null || true

        echo "✅ Worktree and local branch removed."
        ;;
    prune)
        echo "🧹 Pruning stale worktrees..."
        # 1. Purge Git's internal worktree tracking for deleted directories
        for bare in "$BARE_DIR"/*.git; do
            [ -e "$bare" ] || continue
            echo "  Refreshed: $(basename "$bare")"
            git --git-dir="$bare" worktree prune
        done

        # 2. Find and remove local directories that no longer track an active worktree
        # (e.g. if you manually deleted a branch directory but forgot to tell git)
        yq -o=j -I=0 '.repos[] | select(.strategy == "worktree") | .name' "$YAML_FILE" | while read -r repo_name; do
            [ -d "$repo_name" ] || continue
            find "$repo_name" -mindepth 1 -maxdepth 1 -type d | while read -r wt_dir; do
                BARE_REPO_PATH="$BARE_DIR/$repo_name.git"
                # If Git doesn't list this directory as an active worktree, nuke it safely
                if ! git --git-dir="$BARE_REPO_PATH" worktree list | grep -q "\[$(basename "$wt_dir")\]"; then
                    echo "🗑️ Removing orphaned directory: $wt_dir"
                    rm -rf "$wt_dir"
                fi
            done
        done
        echo "✅ Prune complete."
        ;;

    *)
        echo "❌ Unknown command. Available: add, rm, prune"
        exit 1
        ;;
esac
