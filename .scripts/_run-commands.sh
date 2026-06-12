#!/bin/bash
REPO_NAME=$1
TARGET_DIR=$2
YAML_FILE=$3

if [ -z "$REPO_NAME" ] || [ -z "$TARGET_DIR" ] || [ -z "$YAML_FILE" ]; then
    echo "  ❌ Internal Error: Missing arguments in shared executor."
    exit 1
fi

pushd "$TARGET_DIR" > /dev/null || exit 1
echo "  ⚡ Running post-setup automation..."

# 0. global.setup_commands — run in every repo, before its own commands.
if yq ".global | has(\"setup_commands\")" "$YAML_FILE" 2>/dev/null | grep -q "true"; then
    GLOBAL_LIST=$(mktemp)
    yq -o=j -I=0 ".global.setup_commands[]" "$YAML_FILE" 2>/dev/null > "$GLOBAL_LIST"

    while read -r cmd; do
        [ -z "$cmd" ] && continue
        CLEAN_CMD=$(echo "$cmd" | sed -e 's/^"//' -e 's/"$//' | grep -v "null")

        if [ -n "$CLEAN_CMD" ]; then
            echo "  ⚙️ [global] Executing: $CLEAN_CMD"
            if ! eval "$CLEAN_CMD"; then
                echo "  ❌ Error: global setup_command failed -> '$CLEAN_CMD'"
                rm -f "$GLOBAL_LIST"
                popd > /dev/null || exit 1
                exit 1
            fi
        fi
    done < "$GLOBAL_LIST"
    rm -f "$GLOBAL_LIST"
fi

# 1. Single setup_command string
SETUP_CMD=$(yq ".repos[] | select(.name == \"$REPO_NAME\") | .setup_command" "$YAML_FILE" | tr -d '"' | grep -v "null")
if [ -n "$SETUP_CMD" ]; then
    echo "  ⚙️ Executing: $SETUP_CMD"
    if ! eval "$SETUP_CMD"; then
        echo "  ❌ Error: setup_command failed."
        popd > /dev/null || exit 1
        exit 1
    fi
fi

# 2. setup_commands array
if yq ".repos[] | select(.name == \"$REPO_NAME\") | has(\"setup_commands\")" "$YAML_FILE" | grep -q "true"; then
    CMD_LIST=$(mktemp)
    yq -o=j -I=0 ".repos[] | select(.name == \"$REPO_NAME\") | .setup_commands[]" "$YAML_FILE" 2>/dev/null > "$CMD_LIST"

    while read -r cmd; do
        [ -z "$cmd" ] && continue
        CLEAN_CMD=$(echo "$cmd" | sed -e 's/^"//' -e 's/"$//' | grep -v "null")

        if [ -n "$CLEAN_CMD" ]; then
            echo "  ⚙️ Executing: $CLEAN_CMD"
            if ! eval "$CLEAN_CMD"; then
                echo "  ❌ Error: Command failed -> '$CLEAN_CMD'"
                rm -f "$CMD_LIST"
                popd > /dev/null || exit 1
                exit 1
            fi
        fi
    done < "$CMD_LIST"
    rm -f "$CMD_LIST"
fi

popd > /dev/null || exit 1
