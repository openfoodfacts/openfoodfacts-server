#!/usr/bin/env bash
# Generate the .envrc file that isolates this git worktree from other worktrees
# (or other agents) running Docker on the same machine.
#
# Usage:
#   make agent                  # allocate or reuse an id for this worktree
#   make agent ID=myid          # use a specific id instead of the derived one
#   make list-agents            # show which ids are in use, and on which ports
#   make release-agent          # undo: drop this worktree's block and free its port
#
# Without isolation (PO_AGENT_ID unset, the default) every container, network,
# volume, image and host port is shared between worktrees, which makes concurrent
# worktrees fight over port 80 and over Docker DNS names like `backend`.
# Setting PO_AGENT_ID gives the worktree its own names, its own domain and its own
# host port.
#
# No coordination is needed to pick an id: it is derived from the worktree
# directory name, recorded in a per-user registry, and claimed atomically, so two
# agents starting at the same moment cannot end up with the same id. Run
# `make list-agents` to see what is taken.
#
# MongoDB, Redis, PostgreSQL and Keycloak are deliberately NOT isolated: they are
# provided by deps/openfoodfacts-shared-services and deps/openfoodfacts-auth,
# which pin their own compose project names, so all worktrees already share them.
#
# See docs/dev/how-to-run-several-worktrees.md

set -euo pipefail

ID=""
PORT=""
LIST=0
RELEASE=0
ENV_FILE="${ENV_FILE:-.env}"
ENVRC="${ENVRC:-.envrc}"
REGISTRY_DIR="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/off-agents"

# First port handed out, so that we stay well away from the well-known defaults.
PORT_RANGE_START=8081
PORT_RANGE_END=8099

# The generated block in .envrc is delimited by sentinels, and we also strip any
# stray managed key a user may have added by hand outside of a block.
MANAGED='^(export )?(PO_AGENT_ID|PO_AGENT_PREFIX|PO_AGENT_SUFFIX|COMPOSE_PROJECT_NAME|PRODUCT_OPENER_DOMAIN|PRODUCT_OPENER_HOST_PORT|PRODUCT_OPENER_PORT|MINION_QUEUE)='
BEGIN_MARKER='# >>> make agent (generated) >>>'
END_MARKER='# <<< make agent (generated) <<<'

WORKTREE_DIR="$(pwd -P)"

die() {
    echo "❌ $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage:
  $0 [--id <id>] [--port <port>]   allocate or reuse an id for this worktree
  $0 --list                        list the ids in use
  $0 --release                     remove this worktree's block and free its id

Options:
  --id      short lowercase identifier. Defaults to one derived from the
            directory name, so that concurrent agents never have to agree on one.
  --port    host port to publish. Defaults to the first free port from ${PORT_RANGE_START}.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --id)
            ID="${2:-}"
            shift 2
            ;;
        --port)
            PORT="${2:-}"
            shift 2
            ;;
        --list)
            LIST=1
            shift
            ;;
        --release)
            RELEASE=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown argument: $1"
            ;;
    esac
done

# ---------------------------------------------------------------- id handling

sanitize_id() {
    # Lowercase, and keep only characters that are valid in Docker container,
    # network, volume and image names.
    local candidate
    candidate="$(printf '%s' "$1" |
        tr '[:upper:]' '[:lower:]' |
        sed -e 's/[^a-z0-9-]\{1,\}/-/g' -e 's/-\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"
    [ -n "$candidate" ] || candidate="worktree"
    # must start with a letter
    case "$candidate" in
        [0-9]*) candidate="w$candidate" ;;
    esac
    printf '%s' "${candidate:0:20}"
}

# The registry entry for an id is "<port>\n<directory>". Line 2 may be missing for
# entries written by an older version.
registry_entry() {
    [ -f "$REGISTRY_DIR/$1" ] || return 1
    printf '%s' "$(sed -n 1p "$REGISTRY_DIR/$1")"
}

registry_dir_of() {
    [ -f "$REGISTRY_DIR/$1" ] || return 1
    printf '%s' "$(sed -n 2p "$REGISTRY_DIR/$1")"
}

# Claim an id atomically, so that two agents racing cannot both take the same one.
# Prints the claimed id on stdout, returns 1 if it was already taken.
# Sets CLAIMED_ID_FRESH=1 when this call is the one that created the entry, so that
# an abort afterwards does not leave a half-registered worktree behind.
CLAIMED_ID_FRESH=0
CLAIMED_ID=""
CLAIMED_PORT=""
claim_id() {
    local candidate="$1"
    mkdir -p "$REGISTRY_DIR"
    if (set -o noclobber; printf '%s\n%s\n' "${2:-}" "$WORKTREE_DIR" >"$REGISTRY_DIR/$candidate") 2>/dev/null; then
        CLAIMED_ID_FRESH=1
        CLAIMED_ID="$candidate"
        printf '%s' "$candidate"
        return 0
    fi
    return 1
}

# Undo a claim made during this run, so that a failure does not leave a registry
# entry without a port behind.
cleanup_claims() {
    local status=$?
    if [ "$status" -ne 0 ] && [ "$CLAIMED_ID_FRESH" -eq 1 ] && [ -n "$CLAIMED_ID" ]; then
        rm -f "$REGISTRY_DIR/$CLAIMED_ID"
        [ -n "$CLAIMED_PORT" ] && rm -f "$(port_lock "$CLAIMED_PORT")"
    fi
    return $status
}

# ------------------------------------------------------------------- port

port_is_free() {
    # Only fast, non-blocking checks: never attempt a TCP connection here, it can
    # hang for a very long time behind a firewall. This is best effort; the
    # registry is what keeps our own allocations apart.
    local port="$1"
    if command -v docker >/dev/null 2>&1; then
        if docker ps --format '{{.Ports}}' 2>/dev/null | grep -qE "[:.]${port}->"; then
            return 1
        fi
    fi
    if command -v ss >/dev/null 2>&1; then
        if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
            return 1
        fi
    fi
    return 0
}

# Ports are claimed through an empty lock file per port, using the same atomic
# noclobber trick as ids. Without it two agents starting at the same moment both
# see the port as free and both take it, and the second `make dev` then fails with
# "port is already allocated".
port_lock() {
    printf '%s/.port-%s' "$REGISTRY_DIR" "$1"
}

claim_port() {
    local candidate lock
    mkdir -p "$REGISTRY_DIR"
    for candidate in $(seq "$PORT_RANGE_START" "$PORT_RANGE_END"); do
        lock="$(port_lock "$candidate")"
        if (set -o noclobber; : >"$lock") 2>/dev/null; then
            if port_is_free "$candidate"; then
                CLAIMED_PORT="$candidate"
                printf '%s' "$candidate"
                return 0
            fi
            # held by something outside our registry: give the claim back
            rm -f "$lock"
        fi
    done
    return 1
}

# Make sure a port we already own still has its lock, without stealing it from
# whoever holds it.
ensure_port_lock() {
    mkdir -p "$REGISTRY_DIR"
    : >"$(port_lock "$1")"
    CLAIMED_PORT="$1"
}

# ------------------------------------------------------------------- release

if [ "$RELEASE" -eq 1 ]; then
    # ID= lets an operator release a stale entry left by a deleted worktree.
    released_id="$ID"
    [ -n "$released_id" ] || released_id="$(sed -n 's/^export PO_AGENT_ID=//p' "$ENVRC" 2>/dev/null | head -n 1 || true)"
    if [ -n "$released_id" ] && [ -f "$REGISTRY_DIR/$released_id" ]; then
        released_port="$(sed -n 1p "$REGISTRY_DIR/$released_id" 2>/dev/null || true)"
        rm -f "$REGISTRY_DIR/$released_id"
        # give the port back so another worktree can reuse it
        [ -n "$released_port" ] && rm -f "$(port_lock "$released_port")"
    fi
    if [ -f "$ENVRC" ]; then
        TMP="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"
        awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
            $0 == begin { skip = 1; next }
            $0 == end   { skip = 0; next }
            !skip       { print }
        ' "$ENVRC" | grep -Ev "$MANAGED" >"$TMP" || true
        cat "$TMP" >"$ENVRC"
        rm -f "$TMP"
    fi
    if [ -n "$released_id" ]; then
        echo "🥫 Released id '${released_id}' and its port. This worktree is shared again;"
        echo "   existing suffixed volumes and images stay until you remove them with 'make prune'."
    else
        echo "🥫 No generated block found in ${ENVRC}, nothing to release."
    fi
    exit 0
fi

# ----------------------------------------------------------------------- list

if [ "$LIST" -eq 1 ]; then
    if [ ! -d "$REGISTRY_DIR" ] || [ -z "$(ls -A "$REGISTRY_DIR" 2>/dev/null | grep -v '^\.port-' || true)" ]; then
        echo "No worktree is registered yet. Run 'make agent' in a worktree to register one."
        exit 0
    fi
    printf '%-14s %-7s %s\n' "ID" "PORT" "DIRECTORY"
    for entry in "$REGISTRY_DIR"/*; do
        [ -f "$entry" ] || continue
        entry_id="$(basename "$entry")"
        # skip the port lock files
        case "$entry_id" in
            .port-*) continue ;;
        esac
        entry_port="$(sed -n 1p "$entry" 2>/dev/null || true)"
        entry_dir="$(sed -n 2p "$entry" 2>/dev/null || true)"
        [ -n "$entry_dir" ] || entry_dir="(unknown)"
        marker=" "
        # Cross-check against Docker itself: the registry is per user, so another
        # user's worktree would only show up here.
        if command -v docker >/dev/null 2>&1 &&
            docker network inspect "product-opener_${entry_id}" >/dev/null 2>&1; then
            marker="*"
        fi
        printf '%s%-13s %-7s %s\n' "$marker" "$entry_id" "$entry_port" "$entry_dir"
    done
    echo ""
    echo "* = a Docker network still exists for that id, so it is really in use."
    echo "Registry: ${REGISTRY_DIR} (per user; run 'make release-agent' to free a slot)"
    exit 0
fi

# --------------------------------------------------------------------- assign

if [ -n "$ID" ]; then
    # Lowercase letters, digits and dashes only: the value ends up in Docker
    # container, network, volume and image names, all of which are restricted.
    case "$ID" in
        '' | *[!a-z0-9-]* | [0-9-]*)
            die "invalid id '$ID': use lowercase letters, digits and dashes, starting with a letter"
            ;;
    esac
    if [ ${#ID} -gt 20 ]; then
        die "invalid id '$ID': too long (max 20 characters)"
    fi
fi

# From here on we may claim an id and a port: make sure a failure gives them back.
trap cleanup_claims EXIT

# Reuse the id already recorded in .envrc, so that a worktree keeps a stable URL
# across re-runs and the agent never has to remember what it chose.
if [ -z "$ID" ]; then
    ID="$(sed -n 's/^export PO_AGENT_ID=//p' "$ENVRC" 2>/dev/null | head -n 1 || true)"
    [ -n "$ID" ] || ID=""
fi

if [ -z "$ID" ]; then
    # Derive one from the directory name and claim it, adding a discriminator if
    # another worktree already holds it.
    base_id="$(sanitize_id "$(basename "$WORKTREE_DIR")")"
    ID="$base_id"
    for attempt in $(seq 2 99); do
        if ! claim_id "$ID" >/dev/null 2>&1; then
            existing_dir="$(registry_dir_of "$ID" 2>/dev/null || true)"
            if [ "$existing_dir" = "$WORKTREE_DIR" ]; then
                break
            fi
            ID="${base_id:0:17}-${attempt}"
        else
            break
        fi
    done
    if ! registry_dir_of "$ID" >/dev/null 2>&1; then
        die "could not claim an id derived from '$base_id': all variants up to -99 are taken"
    fi
fi

if [ -z "$PORT" ]; then
    PORT="$(registry_entry "$ID" 2>/dev/null || true)"
    [ -n "$PORT" ] || PORT=""
fi

# Read the current owner before we overwrite the entry, so that we can refuse to
# steal an id that another worktree is using.
previous_owner="$(registry_dir_of "$ID" 2>/dev/null || true)"
if [ -n "$previous_owner" ] && [ "$previous_owner" != "$WORKTREE_DIR" ]; then
    die "id '${ID}' is already registered to ${previous_owner}.
   Using it here would make this worktree share its containers, volumes and images.

   Run 'make list-agents' to see the ids in use, drop ID= to get one
   automatically, or free a stale entry with 'make release-agent ID=${ID}'."
fi

if [ -n "$PORT" ]; then
    case "$PORT" in
        '' | *[!0-9]*) die "invalid port '$PORT': expected a number" ;;
    esac
    ensure_port_lock "$PORT"
else
    PORT="$(claim_port)" ||
        die "no free port left in ${PORT_RANGE_START}-${PORT_RANGE_END}."
fi
printf '%s\n%s\n' "$PORT" "$WORKTREE_DIR" >"$REGISTRY_DIR/$ID"

if ! port_is_free "$PORT"; then
    echo "⚠️  port ${PORT} is already in use on this host." >&2
    echo "   Pick another one with 'make agent ID=${ID} PORT=<port>'." >&2
fi

BASE_DOMAIN="$(sed -n 's/^PRODUCT_OPENER_DOMAIN=//p' "$ENV_FILE" 2>/dev/null | head -n 1 || true)"
BASE_DOMAIN="${BASE_DOMAIN:-openfoodfacts.localhost}"

TMP_ENVRC="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"
trap 'rm -f "$TMP_ENVRC"; cleanup_claims' EXIT

if [ -f "$ENVRC" ]; then
    # Keep unrelated lines (USER_UID, USER_GID, CPANMOPTS, DEPS_DIR, ...) so that
    # we never clobber a hand-tuned .envrc.
    # The last awk drops trailing blank lines, so that re-running this script
    # repeatedly does not accumulate them.
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip       { print }
    ' "$ENVRC" |
        grep -Ev "$MANAGED" |
        awk '
            /^[[:space:]]*$/ { blanks++; next }
            { while (blanks > 0) { print ""; blanks-- } print }
        ' >"$TMP_ENVRC" || true
fi

cat >>"$TMP_ENVRC" <<EOF

$BEGIN_MARKER
# Generated by 'make agent' / scripts/dev-agent-env.sh
# Isolates this worktree from other worktrees running on the same machine.
# See docs/dev/how-to-run-several-worktrees.md. Safe to delete this whole block.
#
# Note: COMPOSE_PROJECT_NAME, PRODUCT_OPENER_DOMAIN and MINION_QUEUE are
# deliberately NOT written here: the Makefile derives them from PO_AGENT_ID, so
# writing them too would apply the prefix twice.
export PO_AGENT_ID=${ID}
export PO_AGENT_PREFIX=${ID}_
export PO_AGENT_SUFFIX=_${ID}
export PRODUCT_OPENER_HOST_PORT=${PORT}
export PRODUCT_OPENER_PORT=${PORT}
$END_MARKER
EOF

# Only replace .envrc once we know we can write it.
cat "$TMP_ENVRC" >"$ENVRC"

cat <<EOF
🥫 Worktree '${ID}' is now isolated.

  ${ENVRC} updated (git-ignored, it is a local file).

  URL:          http://world.${ID}.${BASE_DOMAIN}:${PORT}/
  host port:    ${PORT} (recorded for this id in ${REGISTRY_DIR}/${ID})

Next:
  make dev

Run 'make list-agents' to see the other worktrees on this machine.
Undo: make release-agent
EOF
