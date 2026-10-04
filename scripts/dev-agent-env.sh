#!/usr/bin/env bash
# Generate the .envrc files that isolate this git worktree from other worktrees
# (or other agents) running Docker on the same machine.
#
# Usage:
#   make agent                  # allocate or reuse a slot for this worktree
#   make agent ID=myid          # use a specific id instead of the derived one
#   make list-agents            # show which slots are in use
#   make release-agent          # undo: drop the generated blocks and free the slot
#
# Three layers of isolation, all driven by a single id:
#
#   1. Product Opener itself: compose project, networks, volumes, images, domain
#      and host port. Driven by PO_AGENT_PREFIX / PO_AGENT_SUFFIX in the compose
#      files, and by COMPOSE_PROJECT_NAME / PRODUCT_OPENER_DOMAIN in the Makefile.
#
#   2. The shared services (MongoDB, Redis, PostgreSQL) and Keycloak. These are
#      NOT shared between worktrees, and they have to be: Keycloak publishes
#      user-deleted / user-registered / user-updated events to Redis, and every
#      Product Opener instance consumes all three streams (lib/ProductOpener/
#      Redis.pm). A shared Redis would therefore make one worktree react to
#      another worktree's user events, and delete_user_task would rewrite
#      product edits in MongoDB, irreversibly. Since the stream names are
#      global, a per-worktree Keycloak alone would not be enough: Redis has to
#      be per worktree too.
#
#   3. PO_SHARED_DATA=1 opts out of layer 2 and goes back to one shared stack
#      (cheaper, and the only way to see the production data dump in every
#      worktree). It also shares Keycloak, because both have to agree on the
#      network name.
#
# No coordination is needed to pick an id: it is derived from the worktree
# directory name, and the slot is claimed atomically, so two agents starting at
# the same moment cannot end up with the same one. Run `make list-agents` to see
# what is taken.
#
# See docs/dev/how-to-run-several-worktrees.md

set -euo pipefail

ID=""
PORT=""
LIST=0
RELEASE=0
SYNC_DEPS=0
ENV_FILE="${ENV_FILE:-.env}"
ENVRC="${ENVRC:-.envrc}"
REGISTRY_DIR="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/off-agents"

# One slot per worktree, and every host port is derived from it. Claiming a
# single slot is enough to keep the whole set collision-free, which is both
# simpler and race-free compared to claiming each port separately.
#   slot 1 -> frontend 8081, mongodb 8181, postgres 8281, redis 8381,
#             keycloak 8481, keycloak-mgmt 8581, smtp4dev 8681
SLOT_MIN=1
SLOT_MAX=19

# The generated block in .envrc is delimited by sentinels, and we also strip any
# stray managed key a user may have added by hand outside of a block.
MANAGED='^(export )?(PO_AGENT_ID|PO_AGENT_PREFIX|PO_AGENT_SUFFIX|COMPOSE_PROJECT_NAME|PRODUCT_OPENER_DOMAIN|PRODUCT_OPENER_HOST_PORT|PRODUCT_OPENER_PORT|MINION_QUEUE|PO_SHARED_DATA)='
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
  $0 [--id <id>] [--port <port>]   allocate or reuse a slot for this worktree
  $0 --list                        list the slots in use
  $0 --sync-deps                   (re)write the dependencies' .envrc, no allocation
  $0 --release [--id <id>]         remove the generated blocks and free the slot

Options:
  --id      short lowercase identifier. Defaults to one derived from the
            directory name, so that concurrent agents never have to agree on one.
  --port    override the frontend host port. The other ports stay slot-derived.
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
        --sync-deps)
            SYNC_DEPS=1
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

port_for() {
    case "$1" in
        frontend) echo $(($(port_base frontend) + $2)) ;;
        mongodb) echo $(($(port_base mongodb) + $2)) ;;
        postgres) echo $(($(port_base postgres) + $2)) ;;
        redis) echo $(($(port_base redis) + $2)) ;;
        keycloak) echo $(($(port_base keycloak) + $2)) ;;
        keycloak_mgmt) echo $(($(port_base keycloak_mgmt) + $2)) ;;
        smtp4dev) echo $(($(port_base smtp4dev) + $2)) ;;
        *) return 1
        ;;
    esac
}

port_base() {
    case "$1" in
        frontend) echo 8080 ;;
        mongodb) echo 8180 ;;
        postgres) echo 8280 ;;
        redis) echo 8380 ;;
        keycloak) echo 8480 ;;
        keycloak_mgmt) echo 8580 ;;
        smtp4dev) echo 8680 ;;
        *) return 1
        ;;
    esac
}

ALL_SERVICES="frontend mongodb postgres redis keycloak keycloak_mgmt smtp4dev"

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

# The registry entry for an id is "<slot>\n<directory>". Line 2 may be missing for
# entries written by an older version.
registry_slot() {
    [ -f "$REGISTRY_DIR/$1" ] || return 1
    printf '%s' "$(sed -n 1p "$REGISTRY_DIR/$1")"
}

registry_dir_of() {
    [ -f "$REGISTRY_DIR/$1" ] || return 1
    printf '%s' "$(sed -n 2p "$REGISTRY_DIR/$1")"
}

# Two things have to be unique, and they are enforced by two different mechanisms:
#
#   * the slot, so that two worktrees never derive the same host port. Enforced by
#     a .slot-<n> lock file, which is created once and only removed when the slot
#     is released. It is never rewritten, so a concurrent reader can never observe
#     a half-written state.
#   * the id, so that two worktrees never share container, volume and network
#     names. Enforced by writing the id's registry entry with noclobber, once,
#     at the very end. We never delete an id entry while allocating, because that
#     would let another process read an empty entry and wrongly conclude the id is
#     free.
CLAIMED_ID=""
CLAIMED_SLOT=""

claim_slot_lock() {
    mkdir -p "$REGISTRY_DIR"
    (set -o noclobber; : >"$REGISTRY_DIR/.slot-$1") 2>/dev/null
}

release_slot_lock() {
    rm -f "$REGISTRY_DIR/.slot-$1"
}

# usage: write_id_entry <slot> <id>
write_id_entry() {
    (set -o noclobber; printf '%s\n%s\n' "$1" "$WORKTREE_DIR" >"$REGISTRY_DIR/$2") 2>/dev/null
}

# Undo a claim made during this run, so that a failure does not leave a slot locked.
cleanup_claims() {
    local status=$?
    if [ "$status" -ne 0 ] && [ -n "$CLAIMED_SLOT" ]; then
        release_slot_lock "$CLAIMED_SLOT"
    fi
    return $status
}

# ---------------------------------------------------------------------- ports

# Only fast, non-blocking checks: never attempt a TCP connection here, it can
# hang for a very long time behind a firewall. This is best effort; the slot
# registry is what keeps our own allocations apart.
port_is_free() {
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

slot_is_usable() {
    local slot="$1" service port
    for service in $ALL_SERVICES; do
        port="$(port_for "$service" "$slot")"
        port_is_free "$port" || return 1
    done
    return 0
}

sync_dep_envrc() {
    local slot="$1" net mongo postgres redis keycloak keycloak_mgmt smtp4dev

    if [ "$(truthy "${PO_SHARED_DATA:-}")" = "1" ]; then
        remove_all_dep_envrc
        return 0
    fi

    if deps_dir_is_shared; then
        echo "⚠️  DEPS_DIR=${DEPS_ROOT} is outside this worktree, so it is shared with" >&2
        echo "   other worktrees and cannot be isolated: MongoDB, Redis, PostgreSQL and" >&2
        echo "   Keycloak stay shared. Give each worktree its own DEPS_DIR (or drop the" >&2
        echo "   override) to isolate them. See docs/dev/how-to-run-several-worktrees.md" >&2
        return 0
    fi

    net="off_shared_network_${ID}"
    mongo="$(port_for mongodb "$slot")"
    postgres="$(port_for postgres "$slot")"
    redis="$(port_for redis "$slot")"
    keycloak="$(port_for keycloak "$slot")"
    keycloak_mgmt="$(port_for keycloak_mgmt "$slot")"
    smtp4dev="$(port_for smtp4dev "$slot")"

    write_dep_envrc "$SHARED_SERVICES_DIR/.envrc" "\
# Generated by 'make agent' from ${WORKTREE_DIR}
export COMPOSE_PROJECT_NAME=off_shared_${ID}
export COMMON_NET_NAME=${net}
export MONGODB_EXPOSE=127.0.0.1:${mongo}
export POSTGRES_EXPOSE=127.0.0.1:${postgres}
export REDIS_EXPOSE=127.0.0.1:${redis}
# The shared default is 8 GB of WiredTiger cache, which is fine for one instance
# but would exhaust the machine with several worktrees running.
export MONGODB_CACHE_SIZE=${PO_AGENT_MONGO_CACHE_SIZE:-1}"

    write_dep_envrc "$AUTH_DIR/.envrc" "\
# Generated by 'make agent' from ${WORKTREE_DIR}
export COMPOSE_PROJECT_NAME=openfoodfacts-auth_${ID}
# Must match COMMON_NET_NAME of openfoodfacts-shared-services: this is the network
# Keycloak uses to reach Redis and PostgreSQL.
export COMMON_NET_NAME=${net}
export KEYCLOAK_HTTP_PORT=${keycloak}
export KEYCLOAK_MANAGEMENT_PORT=${keycloak_mgmt}
export SMTP4DEV_PORT=${smtp4dev}"
}

truthy() {
    case "$1" in
        1 | true | yes | on) echo 1 ;;
        *) echo "" ;;
    esac
}

# ------------------------------------------------------------------- dep envrc

# Where the dependency checkouts live. The Makefile exports DEPS_DIR, as an
# absolute path; resolve a relative one against the worktree, because that is what
# the dependency Makefiles will do too.
if [ -n "${DEPS_DIR:-}" ]; then
    case "$DEPS_DIR" in
        /*) DEPS_ROOT="$DEPS_DIR" ;;
        *) DEPS_ROOT="$WORKTREE_DIR/$DEPS_DIR" ;;
    esac
else
    DEPS_ROOT="$WORKTREE_DIR/deps"
fi
SHARED_SERVICES_DIR="$DEPS_ROOT/openfoodfacts-shared-services"
AUTH_DIR="$DEPS_ROOT/openfoodfacts-auth"

SHARED_BEGIN='# >>> make agent (generated) >>>'
SHARED_END='# <<< make agent (generated) <<<'

# A shared DEPS_DIR would mean one .envrc per worktree in the same directory,
# which cannot work: worktree A would end up configuring worktree B's services.
deps_dir_is_shared() {
    case "$DEPS_ROOT" in
        "$WORKTREE_DIR" | "$WORKTREE_DIR"/*) return 1 ;;
        *) return 0 ;;
    esac
}

# Strip a sentinel-delimited block from a file, keeping everything else. If
# nothing else is left the file is removed, rather than left behind empty.
strip_block() {
    local file="$1" tmp
    [ -f "$file" ] || return 0
    tmp="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"
    awk -v begin="$2" -v end="$3" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip       { print }
    ' "$file" >"$tmp"
    if [ -s "$tmp" ]; then
        cat "$tmp" >"$file"
    else
        rm -f "$file"
    fi
    rm -f "$tmp"
}

write_dep_envrc() {
    local file="$1" body="$2" tmp
    mkdir -p "$(dirname "$file")"
    strip_block "$file" "$SHARED_BEGIN" "$SHARED_END"
    tmp="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"
    {
        [ -f "$file" ] && cat "$file"
        printf '%s\n' "$SHARED_BEGIN"
        printf '%s\n' "$body"
        printf '%s\n' "$SHARED_END"
    } >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

remove_dep_envrc() {
    strip_block "$1" "$SHARED_BEGIN" "$SHARED_END"
}

remove_all_dep_envrc() {
    remove_dep_envrc "$SHARED_SERVICES_DIR/.envrc"
    remove_dep_envrc "$AUTH_DIR/.envrc"
}

# Write (or refresh) the .envrc of the two dependency projects. Called both by
# `make agent` and by `make run_deps`, so that a worktree cloned before
# `make agent` still ends up consistent.
# ------------------------------------------------------------------- release

if [ "$RELEASE" -eq 1 ]; then
    released_id="$ID"
    [ -n "$released_id" ] || released_id="$(sed -n 's/^export PO_AGENT_ID=//p' "$ENVRC" 2>/dev/null | head -n 1 || true)"
    if [ -n "$released_id" ] && [ -f "$REGISTRY_DIR/$released_id" ]; then
        release_slot_lock "$(sed -n 1p "$REGISTRY_DIR/$released_id" 2>/dev/null || true)"
        rm -f "$REGISTRY_DIR/$released_id"
    fi
    remove_all_dep_envrc
    if [ -f "$ENVRC" ]; then
        strip_block "$ENVRC" "$BEGIN_MARKER" "$END_MARKER"
        # also drop stray managed keys a user may have added outside a block
        TMP="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"
        grep -Ev "$MANAGED" "$ENVRC" >"$TMP" || true
        if [ -s "$TMP" ]; then cat "$TMP" >"$ENVRC"; else rm -f "$ENVRC"; fi
        rm -f "$TMP"
    fi
    if [ -n "$released_id" ]; then
        echo "🥫 Released id '${released_id}' and its ports. This worktree is shared again;"
        echo "   existing suffixed volumes and images stay until you remove them with 'make prune'."
    else
        echo "🥫 No generated block found in ${ENVRC}, nothing to release."
    fi
    exit 0
fi

# ----------------------------------------------------------------------- list

if [ "$LIST" -eq 1 ]; then
    if [ ! -d "$REGISTRY_DIR" ] || [ -z "$(ls -A "$REGISTRY_DIR" 2>/dev/null | grep -v '^\.slot-' || true)" ]; then
        echo "No worktree is registered yet. Run 'make agent' in a worktree to register one."
        exit 0
    fi
    printf '%-14s %-7s %-7s %-7s %-7s %s\n' "ID" "SLOT" "FRONTEND" "MONGO" "KEYCLOAK" "DIRECTORY"
    for entry in "$REGISTRY_DIR"/*; do
        [ -f "$entry" ] || continue
        entry_id="$(basename "$entry")"
        case "$entry_id" in
            .slot-*) continue ;;
        esac
        entry_slot="$(sed -n 1p "$entry" 2>/dev/null || true)"
        entry_dir="$(sed -n 2p "$entry" 2>/dev/null || true)"
        [ -n "$entry_dir" ] || entry_dir="(unknown)"
        case "$entry_slot" in
            '' | *[!0-9]*) entry_slot="?" ;;
        esac
        printf '%-14s %-7s %-7s %-7s %-7s %s\n' \
            "$entry_id" "$entry_slot" \
            "$(port_for frontend "$entry_slot" 2>/dev/null || echo '-')" \
            "$(port_for mongodb "$entry_slot" 2>/dev/null || echo '-')" \
            "$(port_for keycloak "$entry_slot" 2>/dev/null || echo '-')" \
            "$entry_dir"
    done
    echo ""
    echo "Slots are handed out from 1 to ${SLOT_MAX}; every service port is derived from the slot."
    echo "Registry: ${REGISTRY_DIR} (per user; run 'make release-agent' to free a slot)"
    exit 0
fi

# ---------------------------------------------------------------------- sync

# From here on we may claim a slot: make sure a failure gives it back.
trap cleanup_claims EXIT

if [ "$SYNC_DEPS" -eq 1 ]; then
    ID="$(sed -n 's/^export PO_AGENT_ID=//p' "$ENVRC" 2>/dev/null | head -n 1 || true)"
    if [ -z "$ID" ]; then
        # Not isolated: make sure no leftover from a previous run survives.
        remove_all_dep_envrc
        exit 0
    fi
    CLAIMED_ID="$ID"
    SLOT="$(registry_slot "$ID" 2>/dev/null || true)"
    if [ -z "$SLOT" ]; then
        echo "❌ '${ID}' is not in the agent registry (${REGISTRY_DIR})." >&2
        echo "   Run 'make agent' again to re-register it." >&2
        exit 1
    fi
    sync_dep_envrc "$SLOT"
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

# Reuse the id already recorded in .envrc, so that a worktree keeps a stable URL
# across re-runs and the agent never has to remember what it chose.
if [ -z "$ID" ]; then
    ID="$(sed -n 's/^export PO_AGENT_ID=//p' "$ENVRC" 2>/dev/null | head -n 1 || true)"
    [ -n "$ID" ] || ID=""
fi

# Candidate ids to try: the explicit one, or the derived one plus a -2, -3, ...
# discriminator for every other worktree whose directory sanitises to the same
# name.
CANDIDATE_IDS=()
if [ -n "$ID" ]; then
    CANDIDATE_IDS=("$ID")
else
    base_id="$(sanitize_id "$(basename "$WORKTREE_DIR")")"
    for attempt in $(seq 1 "$SLOT_MAX"); do
        if [ "$attempt" -eq 1 ]; then
            CANDIDATE_IDS+=("$base_id")
        else
            CANDIDATE_IDS+=("${base_id:0:17}-${attempt}")
        fi
    done
fi

SLOT=""

# Take the first slot whose ports are all actually free: a slot can be held by an
# unrelated process on the host, and skipping it is better than failing.
acquire() {
    local candidate owner stored attempt
    for candidate in "${CANDIDATE_IDS[@]}"; do
        CLAIMED_ID="$candidate"
        owner="$(registry_dir_of "$candidate" 2>/dev/null || true)"
        if [ -n "$owner" ] && [ "$owner" != "$WORKTREE_DIR" ]; then
            # Somebody else already owns this id: do not steal it.
            if [ "$candidate" = "${CANDIDATE_IDS[0]}" ] && [ "${#CANDIDATE_IDS[@]}" -eq 1 ]; then
                die "id '${candidate}' is already registered to ${owner}.
   Using it here would make this worktree share its containers, volumes and images.

   Run 'make list-agents' to see the ids in use, drop ID= to get one
   automatically, or free a stale entry with 'make release-agent ID=${candidate}'."
            fi
            continue
        fi
        # Our own entry from a previous run: keep the slot if it is still usable.
        if [ -n "$owner" ]; then
            stored="$(registry_slot "$candidate" 2>/dev/null || true)"
            case "$stored" in
                '' | *[!0-9]*) stored="" ;;
            esac
            if [ -n "$stored" ] && slot_is_usable "$stored"; then
                ID="$candidate"
                SLOT="$stored"
                CLAIMED_SLOT=""
                return 0
            fi
        fi
        for attempt in $(seq "$SLOT_MIN" "$SLOT_MAX"); do
            claim_slot_lock "$attempt" || continue
            # we hold the slot lock from here on, so no one else can pick it
            if ! slot_is_usable "$attempt"; then
                release_slot_lock "$attempt"
                continue
            fi
            if write_id_entry "$attempt" "$candidate"; then
                ID="$candidate"
                SLOT="$attempt"
                CLAIMED_SLOT="$attempt"
                return 0
            fi
            # the id was taken between our check and the write
            release_slot_lock "$attempt"
        done
    done
    return 1
}

acquire ||
    die "no free slot left (${SLOT_MIN}-${SLOT_MAX}) for this worktree: every derived host port is in use.
   Free one with 'make release-agent', or stop whatever is holding them."

if [ -n "$PORT" ]; then
    case "$PORT" in
        '' | *[!0-9]*) die "invalid port '$PORT': expected a number" ;;
    esac
    FRONTEND_PORT="$PORT"
else
    FRONTEND_PORT="$(port_for frontend "$SLOT")"
fi

# Make sure we did not inherit a slot whose ports somebody else already took.
if ! slot_is_usable "$SLOT"; then
    busy=""
    for service in $ALL_SERVICES; do
        port="$(port_for "$service" "$SLOT")"
        port_is_free "$port" || busy="$busy $service($port)"
    done
    die "slot ${SLOT} is already in use on this host:${busy:- unknown}.
   Free the port, or pass PORT= to place the frontend elsewhere."
fi

BASE_DOMAIN="$(sed -n 's/^PRODUCT_OPENER_DOMAIN=//p' "$ENV_FILE" 2>/dev/null | head -n 1 || true)"
BASE_DOMAIN="${BASE_DOMAIN:-openfoodfacts.localhost}"

TMP_ENVRC="$(mktemp "${TMPDIR:-/tmp}/envrc.XXXXXX")"

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

# Persist PO_SHARED_DATA so that a later `make dev` without the environment
# variable keeps behaving the same way.
SHARED_DATA_LINE=""
if [ "$(truthy "${PO_SHARED_DATA:-}")" = "1" ]; then
    SHARED_DATA_LINE="export PO_SHARED_DATA=1
"
fi

cat >>"$TMP_ENVRC" <<EOF

$BEGIN_MARKER
# Generated by 'make agent' / scripts/dev-agent-env.sh
# Isolates this worktree from other worktrees running on the same machine,
# including MongoDB, Redis, PostgreSQL and Keycloak. See
# docs/dev/how-to-run-several-worktrees.md. Safe to delete this whole block.
#
# Note: COMPOSE_PROJECT_NAME, PRODUCT_OPENER_DOMAIN and MINION_QUEUE are
# deliberately NOT written here: the Makefile derives them from PO_AGENT_ID, so
# writing them too would apply the prefix twice.
export PO_AGENT_ID=${ID}
export PO_AGENT_PREFIX=${ID}_
export PO_AGENT_SUFFIX=_${ID}
export PRODUCT_OPENER_HOST_PORT=${FRONTEND_PORT}
export PRODUCT_OPENER_PORT=${FRONTEND_PORT}
$SHARED_DATA_LINE$END_MARKER
EOF

# Only replace .envrc once we know we can write it.
cat "$TMP_ENVRC" >"$ENVRC"
rm -f "$TMP_ENVRC"

sync_dep_envrc "$SLOT"

cat <<EOF
🥫 Worktree '${ID}' is now isolated (slot ${SLOT}).

  ${ENVRC} updated (git-ignored, it is a local file).

  URL:        http://world.${ID}.${BASE_DOMAIN}:${FRONTEND_PORT}/
  frontend:   ${FRONTEND_PORT}
  mongodb:    $(port_for mongodb "$SLOT")
  postgres:   $(port_for postgres "$SLOT")
  redis:      $(port_for redis "$SLOT")
  keycloak:   $(port_for keycloak "$SLOT")
  smtp4dev:   $(port_for smtp4dev "$SLOT")

  dependencies: MongoDB, Redis, PostgreSQL and Keycloak get their own containers
  and their own network (off_shared_network_${ID}). Set PO_SHARED_DATA=1 in .envrc
  to go back to one shared stack.

Next:
  make dev

Run 'make list-agents' to see the other worktrees on this machine.
Undo: make release-agent
EOF
