#!/bin/bash
# Add a new repo to repos.yaml and check it out.
#
#   mise run add <url>
#   mise run add <url> --name foo --branch develop
#   mise run add <url> --description "..." --setupCommands="npm i, npm run build"
#   mise run add <url> --tags "backend,core" --no-clone
#
# With a TTY and missing values, it prompts for name / description / branch /
# setup-commands. Pass the matching flag to skip a prompt; pass --yes to take
# every default with no prompts at all.
set -euo pipefail

YAML_FILE="$(pwd)/repos.yaml"
[ -f "$YAML_FILE" ] || { echo "❌ repos.yaml not found. Run from the workspace root."; exit 1; }

URL=""
NAME="" ; DESCRIPTION="" ; BRANCH="" ; SETUP_RAW="" ; TAGS_RAW=""
HAVE_NAME=0 ; HAVE_DESC=0 ; HAVE_BRANCH=0 ; HAVE_SETUP=0
ASSUME_YES=0 ; CLONE=1

# --flag value | --flag=value
val() { case "$1" in *=*) printf '%s' "${1#*=}";; *) printf '%s' "$2";; esac; }
shiftn() { case "$1" in *=*) return 1;; *) return 0;; esac; }  # 0 => consumed a second token

# When invoked via `mise run add`, mise parses args per the usage spec in
# mise.toml and hands them over as usage_* env vars (not $@). Seed from those;
# any positional args below still override them (direct ./.scripts/add.sh use).
URL="${usage_url:-$URL}"
[ -n "${usage_name:-}" ]           && { NAME="$usage_name"; HAVE_NAME=1; }
[ -n "${usage_description:-}" ]     && { DESCRIPTION="$usage_description"; HAVE_DESC=1; }
[ -n "${usage_default_branch:-}" ] && { BRANCH="$usage_default_branch"; HAVE_BRANCH=1; }
[ -n "${usage_setup_commands:-}" ] && { SETUP_RAW="$usage_setup_commands"; HAVE_SETUP=1; }
[ -n "${usage_tags:-}" ]           && TAGS_RAW="$usage_tags"
[ "${usage_no_clone:-}" = "true" ] && CLONE=0
[ "${usage_yes:-}" = "true" ]      && ASSUME_YES=1

while [ $# -gt 0 ]; do
    case "$1" in
        --name)        NAME=$(val "$1" "${2:-}"); HAVE_NAME=1; shiftn "$1" && shift; shift;;
        --name=*)      NAME=${1#*=}; HAVE_NAME=1; shift;;
        --description) DESCRIPTION=$(val "$1" "${2:-}"); HAVE_DESC=1; shiftn "$1" && shift; shift;;
        --description=*) DESCRIPTION=${1#*=}; HAVE_DESC=1; shift;;
        --branch|--defaultBranch) BRANCH=$(val "$1" "${2:-}"); HAVE_BRANCH=1; shiftn "$1" && shift; shift;;
        --branch=*|--defaultBranch=*) BRANCH=${1#*=}; HAVE_BRANCH=1; shift;;
        --setupCommands|--setup-commands) SETUP_RAW=$(val "$1" "${2:-}"); HAVE_SETUP=1; shiftn "$1" && shift; shift;;
        --setupCommands=*|--setup-commands=*) SETUP_RAW=${1#*=}; HAVE_SETUP=1; shift;;
        --tags)        TAGS_RAW=$(val "$1" "${2:-}"); shiftn "$1" && shift; shift;;
        --tags=*)      TAGS_RAW=${1#*=}; shift;;
        --no-clone)    CLONE=0; shift;;
        -y|--yes)      ASSUME_YES=1; shift;;
        -h|--help)     sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
        -*)            echo "❌ Unknown flag: $1"; exit 1;;
        *)             [ -z "$URL" ] && URL="$1" || { echo "❌ Unexpected arg: $1"; exit 1; }; shift;;
    esac
done

[ -n "$URL" ] || { echo "❌ Usage: mise run add <git-url> [--name … --branch … --description … --setupCommands … --tags …]"; exit 1; }

interactive() { [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; }
ask() { # ask <prompt> <default> ; echoes the answer
    local prompt=$1 default=$2 reply
    if interactive; then
        read -r -p "$prompt [$default]: " reply </dev/tty || true
        printf '%s' "${reply:-$default}"
    else
        printf '%s' "$default"
    fi
}

# owner/repo from git@host:owner/repo.git or https://host/owner/repo(.git)
slug_from_url() { printf '%s' "$1" | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##'; }
DEFAULT_NAME=$(basename "$(slug_from_url "$URL")")

# --- name ---
[ "$HAVE_NAME" -eq 1 ] || NAME=$(ask "Name" "$DEFAULT_NAME")
NAME=${NAME:-$DEFAULT_NAME}

# Reject duplicates up front.
if NAME="$NAME" yq -e '.repos[] | select(.name == strenv(NAME)) | .name' "$YAML_FILE" >/dev/null 2>&1; then
    echo "❌ '$NAME' is already in repos.yaml."; exit 1
fi

# --- description (default: GitHub's, via gh) ---
if [ "$HAVE_DESC" -eq 0 ]; then
    GH_DESC=""
    if command -v gh >/dev/null 2>&1; then
        GH_DESC=$(gh repo view "$(slug_from_url "$URL")" --json description -q .description 2>/dev/null || true)
    fi
    DESCRIPTION=$(ask "Description" "$GH_DESC")
fi

# --- branch ---
[ "$HAVE_BRANCH" -eq 1 ] || BRANCH=$(ask "Default branch" "main")
BRANCH=${BRANCH:-main}

# --- setup commands (comma-separated; empty = none) ---
if [ "$HAVE_SETUP" -eq 0 ]; then
    SETUP_RAW=$(ask "Setup commands (comma-separated, blank to skip)" "")
fi

echo "✍️  Writing repos.yaml entry for '$NAME'…"
NAME="$NAME" URL="$URL" BRANCH="$BRANCH" \
    yq -i '.repos += [{"name": strenv(NAME), "url": strenv(URL), "branch": strenv(BRANCH)}]' "$YAML_FILE"

if [ -n "$TAGS_RAW" ]; then
    TAGS="$(printf '%s' "$TAGS_RAW" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | paste -sd'\n' -)" \
        yq -i '.repos[-1].tags = (strenv(TAGS) | split("\n"))' "$YAML_FILE"
fi

if [ -n "$DESCRIPTION" ]; then
    DESCRIPTION="$DESCRIPTION" yq -i '.repos[-1].description = strenv(DESCRIPTION) | .repos[-1].description style="literal"' "$YAML_FILE"
fi

# Split setup commands on commas, trim, drop blanks → YAML array.
CMDS="$(printf '%s' "$SETUP_RAW" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' || true)"
if [ -n "$CMDS" ]; then
    CMDS="$CMDS" yq -i '.repos[-1].setup_commands = (strenv(CMDS) | split("\n"))' "$YAML_FILE"
fi

echo "✅ Added '$NAME' to repos.yaml."

if [ "$CLONE" -eq 0 ]; then
    echo "ℹ️  --no-clone set; run 'mise run setup' to check it out later."
    exit 0
fi

if [ -d "$NAME" ]; then
    echo "⚠️  Directory '$NAME' already exists — skipping clone."
    exit 0
fi

echo "📦 Cloning $NAME ($BRANCH)…"
git clone -b "$BRANCH" "$URL" "$NAME"
./.scripts/_run-commands.sh "$NAME" "$NAME" "$YAML_FILE"
echo "✅ '$NAME' is checked out and provisioned."
