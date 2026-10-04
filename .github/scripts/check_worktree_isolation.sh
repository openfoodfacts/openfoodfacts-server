#!/usr/bin/env bash
# Check that per-worktree isolation (PO_AGENT_ID) is wired up correctly.
#
# Three things are asserted, in the order they happen at runtime:
#  1. scripts/dev-agent-env.sh generates the expected .envrc values;
#  2. the Makefile derives the matching compose project name, domain and ports;
#  3. docker compose resolves a fully suffixed set of networks, volumes, images,
#     aliases and host ports for the isolated worktree, while the default
#     (PO_AGENT_ID unset) stays byte-identical to the historical configuration.
#
# We only resolve configuration, we never start containers, so this needs neither
# built images nor running services.
#
# See docs/dev/how-to-run-several-worktrees.md

set -euo pipefail

cd "$(dirname "$0")/../.."
REPO_ROOT="$PWD"

COMPOSE_FILES="docker-compose.yml;docker/dev.yml"
AGENT_ID="ci1"
AGENT_PORT="8081"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
# keep the port registry out of the way so the check is deterministic
export XDG_CACHE_HOME="$WORK_DIR/cache"

fail() {
    echo "❌ $*" >&2
    exit 1
}

# 0. concurrent worktrees must not have to agree on an id: `make agent` with no ID
# derives one from the directory name and claims it atomically, and `make list-agents`
# reports what is taken. Race a few directories sharing a basename.
COORD="$WORK_DIR/coord"
for i in 1 2 3 4 5; do
    mkdir -p "$COORD/p$i/shared-name"
done
# background the subshells themselves, so that `wait` really waits for them
for i in 1 2 3 4 5; do
    (
        cd "$COORD/p$i/shared-name"
        XDG_CACHE_HOME="$COORD/cache" ENVRC="$COORD/p$i/shared-name/.envrc" \
            DEPS_DIR="$COORD/cache" "$REPO_ROOT/scripts/dev-agent-env.sh" >/dev/null 2>&1
    ) &
done
wait

# give any straggler a moment to write its entry (slow CI disks)
for _ in 1 2 3 4 5 6 7 8 9 10; do
    registered="$(find "$COORD/cache/off-agents" -maxdepth 1 -type f ! -name '.port-*' 2>/dev/null | grep -c . || true)"
    [ "$registered" -ge 5 ] && break
    sleep 1
done

mapfile -t COORD_IDS < <(
    for entry in "$COORD/cache/off-agents"/*; do
        case "$(basename "$entry")" in
            .port-*) continue ;;
        esac
        basename "$entry"
    done
)
mapfile -t COORD_SLOTS < <(
    for entry in "$COORD/cache/off-agents"/*; do
        case "$(basename "$entry")" in
            .slot-*) continue ;;
        esac
        sed -n 1p "$entry"
    done
)
# the frontend port of a slot is 8080 + slot
COORD_PORTS=()
for slot in "${COORD_SLOTS[@]}"; do
    COORD_PORTS+=("$((8080 + slot))")
done

[ "${#COORD_IDS[@]}" -eq 5 ] ||
    fail "expected 5 registered worktrees, got ${#COORD_IDS[@]}: ${COORD_IDS[*]}"
[ "$(printf '%s\n' "${COORD_IDS[@]}" | sort -u | grep -c .)" -eq 5 ] ||
    fail "two worktrees got the same id: ${COORD_IDS[*]}"
[ "$(printf '%s\n' "${COORD_SLOTS[@]}" | sort -u | grep -c .)" -eq 5 ] ||
    fail "two worktrees got the same slot: ${COORD_SLOTS[*]}"
[ "$(printf '%s\n' "${COORD_PORTS[@]}" | sort -u | grep -c .)" -eq 5 ] ||
    fail "two worktrees got the same frontend port: ${COORD_PORTS[*]}"
for slot in "${COORD_SLOTS[@]}"; do
    case "$slot" in
        '' | *[!0-9]*) fail "a worktree was registered with a non-numeric slot: ${COORD_IDS[*]}" ;;
    esac
done
echo "✅ concurrent worktrees derive distinct ids, slots and ports without coordinating"

# 1. the generator. Run it from a throwaway worktree so that it writes its
# .envrc files there instead of into the real deps/ checkouts.
WT="$WORK_DIR/wt"
mkdir -p "$WT"
(cd "$WT" && ENVRC="$WT/.envrc" "$REPO_ROOT/scripts/dev-agent-env.sh" --id "$AGENT_ID" --port "$AGENT_PORT" >/dev/null)
cp "$WT/.envrc" "$WORK_DIR/envrc"

for expected in \
    "export PO_AGENT_ID=${AGENT_ID}" \
    "export PO_AGENT_PREFIX=${AGENT_ID}_" \
    "export PO_AGENT_SUFFIX=_${AGENT_ID}" \
    "export PRODUCT_OPENER_HOST_PORT=${AGENT_PORT}" \
    "export PRODUCT_OPENER_PORT=${AGENT_PORT}"; do
    grep -qxF "$expected" "$WORK_DIR/envrc" ||
        fail "generated .envrc is missing '$expected'"
done
# COMPOSE_PROJECT_NAME and PRODUCT_OPENER_DOMAIN are derived by the Makefile:
# if the generator wrote them too, they would get the prefix applied twice.
for forbidden in COMPOSE_PROJECT_NAME PRODUCT_OPENER_DOMAIN MINION_QUEUE; do
    if grep -qE "^export ${forbidden}=" "$WORK_DIR/envrc"; then
        fail "generated .envrc must not set ${forbidden} (the Makefile derives it)"
    fi
done
echo "✅ the generator writes the expected .envrc"

# MongoDB, Redis, PostgreSQL and Keycloak must be isolated too, because Keycloak
# publishes user-deleted/user-registered/user-updated to Redis and every instance
# consumes all three streams: a shared Redis would make one worktree act on
# another worktree's user events.
for dep in openfoodfacts-shared-services openfoodfacts-auth; do
    grep -qx "export COMMON_NET_NAME=off_shared_network_${AGENT_ID}" \
        "$WT/deps/$dep/.envrc" ||
        fail "$dep/.envrc does not isolate the shared network"
done
grep -qx "export COMPOSE_PROJECT_NAME=off_shared_${AGENT_ID}" \
    "$WT/deps/openfoodfacts-shared-services/.envrc" ||
    fail "openfoodfacts-shared-services is not isolated"
grep -qx "export COMPOSE_PROJECT_NAME=openfoodfacts-auth_${AGENT_ID}" \
    "$WT/deps/openfoodfacts-auth/.envrc" ||
    fail "openfoodfacts-auth is not isolated"
# and every dependency port must differ from the shared default
AGENT_SLOT="$(sed -n 1p "$XDG_CACHE_HOME/off-agents/$AGENT_ID")"
for entry in "openfoodfacts-shared-services 127.0.0.1:$((8180 + AGENT_SLOT))" \
            "openfoodfacts-auth ${AGENT_ID} $((8480 + AGENT_SLOT))"; do
    dep="${entry%% *}"
    rest="${entry#* }"
    needle="${rest#* }"
    grep -qF "$needle" "$WT/deps/$dep/.envrc" ||
        fail "$dep does not carry its isolated port ${needle}"
done
echo "✅ MongoDB, Redis, PostgreSQL and Keycloak are isolated per worktree"

# PO_SHARED_DATA=1 must opt back out, and be remembered in .envrc
(cd "$WT" && PO_SHARED_DATA=1 ENVRC="$WT/.envrc" "$REPO_ROOT/scripts/dev-agent-env.sh" >/dev/null)
grep -qx "export PO_SHARED_DATA=1" "$WT/.envrc" || fail "PO_SHARED_DATA=1 was not persisted"
cp "$WT/.envrc" "$WORK_DIR/envrc"
[ ! -e "$WT/deps/openfoodfacts-shared-services/.envrc" ] ||
    fail "PO_SHARED_DATA=1 should have removed the shared-services .envrc"
echo "✅ PO_SHARED_DATA=1 shares the dependencies again, and is persisted"
# back to fully isolated, and pin the port again for the assertions below
(cd "$WT" && "$REPO_ROOT/scripts/dev-agent-env.sh" --id "$AGENT_ID" --port "$AGENT_PORT" >/dev/null)
cp "$WT/.envrc" "$WORK_DIR/envrc"

# An id that belongs to another worktree must be refused, not silently shared.
OTHER="$WORK_DIR/other"
mkdir -p "$OTHER"
STOLEN_ID="${COORD_IDS[0]}"
if XDG_CACHE_HOME="$COORD/cache" ENVRC="$OTHER/.envrc" \
    ./scripts/dev-agent-env.sh --id "$STOLEN_ID" >/dev/null 2>&1; then
    fail "claiming id '$STOLEN_ID' owned by another worktree should have failed"
fi
echo "✅ an id owned by another worktree is refused"

# A DEPS_DIR shared with other worktrees cannot be isolated, and the generator has
# to say so rather than write per-worktree values into a common directory.
SHARED_DEPS_OUT="$(cd "$WT" && DEPS_DIR=/tmp/elsewhere ENVRC="$WT/.envrc" "$REPO_ROOT/scripts/dev-agent-env.sh" --id "$AGENT_ID" 2>&1 >/dev/null || true)"
case "$SHARED_DEPS_OUT" in
    *"is outside this worktree"*) ;;
    *) fail "a DEPS_DIR outside the worktree should be reported as shared, got: $SHARED_DEPS_OUT" ;;
esac
echo "✅ a DEPS_DIR shared with other worktrees is refused, not silently overwritten"

# 2. the Makefile derivation. We point ENVRC at the generated file rather than at
# .envrc: make includes it after .env, and an assignment in a makefile always beats
# an inherited environment variable, so a shell export cannot override .env.
effective="$(make --no-print-directory ENVRC="$WORK_DIR/envrc" print-agent-config)"

# Keep only the assignments. On a fresh checkout `make` first regenerates
# .test_groups_cache/{unit,integration}_groups.mk, and those recipes print their
# own banners ("Generating dynamic unit test groups ...") on stdout before our
# target's output. That output is legitimate make noise, but it must not be
# mistaken for configuration, so it is dropped here rather than being executed
# further down.
effective="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' <<<"$effective")"

[ -n "$effective" ] ||
    fail "make print-agent-config printed no variable assignment at all"

for pair in \
    "COMPOSE_PROJECT_NAME=po_off_${AGENT_ID}" \
    "PRODUCT_OPENER_DOMAIN=${AGENT_ID}.openfoodfacts.localhost" \
    "PRODUCT_OPENER_HOST_PORT=${AGENT_PORT}" \
    "PRODUCT_OPENER_PORT=${AGENT_PORT}" \
    "MINION_QUEUE=${AGENT_ID}.openfoodfacts.localhost"; do
    grep -qxF "$pair" <<<"$effective" ||
        fail "make print-agent-config did not derive '$pair'"
done
echo "✅ the Makefile derives the isolated names"

# 3. what docker compose makes of it
#
# The values are exported inside a subshell rather than passed to `env` as an
# argument list. `env` executes the first argument that is not a KEY=VALUE
# assignment, so feeding it unvalidated `make` output means that any stray line
# (a banner, a warning) is run as a command, which fails with a baffling
# "env: '<line>': No such file or directory". Exporting also keeps values that
# contain spaces intact, which an unquoted expansion would word-split.
command -v docker >/dev/null 2>&1 ||
    fail "docker is required to resolve the compose configuration"

compose_config_with() {
    local values="$1" line key
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" != *=* ]]; then
            echo "not a KEY=VALUE line: $line" >&2
            return 1
        fi
        key="${line%%=*}"
        if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            echo "not a valid variable name: $line" >&2
            return 1
        fi
        export "$key=${line#*=}"
    done <<<"$values"
    COMPOSE_FILE="$COMPOSE_FILES" docker compose --env-file=.env config --format json
}

DEFAULT_JSON="$(COMPOSE_FILE="$COMPOSE_FILES" docker compose --env-file=.env config --format json)"
AGENT_JSON="$(compose_config_with "$effective")" ||
    fail "could not turn the derived values into environment variables"

python3 - "$DEFAULT_JSON" "$AGENT_JSON" "$AGENT_ID" "$AGENT_PORT" <<'PY'
import json
import sys

default = json.loads(sys.argv[1])
agent = json.loads(sys.argv[2])
agent_id = sys.argv[3]
port = sys.argv[4]
prefix, suffix = agent_id + "_", "_" + agent_id

errors = []


def want(cfg, label, actual, expected):
    if actual != expected:
        errors.append(f"{label}: expected {expected!r}, got {actual!r}")


# The default path must be untouched, so that existing single-worktree setups and
# the deployments keep working exactly as before.
want(default, "default project name", default.get("name"), "po_off")
want(default, "default network", default["networks"]["default"]["name"], "product-opener")
want(default, "default minion_db network", default["networks"]["minion_db"]["name"], "minion_db")
want(default, "default users volume", default["volumes"]["users"]["name"], "po_users")
want(default, "default product_images volume",
     default["volumes"]["product_images"]["name"], "po_off_product_images")
want(default, "default backend image",
     default["services"]["backend"]["image"], "openfoodfacts-server/backend:dev")
want(default, "default frontend port",
     [str(p.get("published")) for p in default["services"]["frontend"]["ports"]], ["80"])
want(default, "default frontend aliases",
     sorted(default["services"]["frontend"]["networks"]["default"]["aliases"]),
     sorted(["openfoodfacts.localhost", "world.openfoodfacts.localhost",
             "static.openfoodfacts.localhost", "images.openfoodfacts.localhost",
             "fr.openfoodfacts.localhost", "world-be.openfoodfacts.localhost",
             "world-de.openfoodfacts.localhost", "world-it.openfoodfacts.localhost",
             "es-it.openfoodfacts.localhost", "ch-it.openfoodfacts.localhost",
             "ssl-api.openfoodfacts.localhost", "fr.pro.openfoodfacts.localhost",
             "world.pro.openfoodfacts.localhost", "auth.openfoodfacts.localhost",
             "es.openfoodfacts.localhost", "be-fr.openfoodfacts.localhost"]))

# The isolated path must be suffixed, so that two worktrees cannot collide.
want(agent, "isolated project name", agent.get("name"), "po_off_" + agent_id)
want(agent, "isolated network", agent["networks"]["default"]["name"], "product-opener" + suffix)
want(agent, "isolated minion_db network", agent["networks"]["minion_db"]["name"],
     prefix + "minion_db")
want(agent, "isolated frontend port",
     [str(p.get("published")) for p in agent["services"]["frontend"]["ports"]], [port])
want(agent, "isolated frontend domain",
     agent["services"]["frontend"]["environment"]["PRODUCT_OPENER_DOMAIN"],
     agent_id + ".openfoodfacts.localhost")

# The volumes that used to be hardcoded across projects
for volume in ("users", "orgs", "export_files", "product_images"):
    want(agent, f"isolated {volume} volume",
         agent["volumes"][volume]["name"], prefix + default["volumes"][volume]["name"])

# ... and nothing else may be left shared
for name, spec in agent["volumes"].items():
    resolved = spec.get("name") or f"{agent['name']}_{name}"
    if agent_id not in resolved:
        errors.append(f"volume {name} is not isolated: {resolved}")
for name, spec in agent["networks"].items():
    resolved = spec.get("name") or f"{agent['name']}_{name}"
    if agent_id not in resolved:
        errors.append(f"network {name} is not isolated: {resolved}")
for service, spec in agent["services"].items():
    image = spec.get("image", "")
    if image.startswith("openfoodfacts-server/") and not image.endswith(suffix):
        errors.append(f"image for {service} is not isolated: {image}")

aliases = agent["services"]["frontend"]["networks"]["default"]["aliases"]
if len(aliases) != len(set(aliases)):
    errors.append(f"duplicate frontend aliases: {aliases}")
# every alias has to carry the agent label, including the ones built as
# <label>.<domain>, e.g. world.ci1.openfoodfacts.localhost
expected_suffix = f"{agent_id}.openfoodfacts.localhost"
for alias in aliases:
    if expected_suffix not in alias:
        errors.append(f"frontend alias is not isolated: {alias}")

if errors:
    print("❌ per-worktree isolation check failed:", file=sys.stderr)
    for error in errors:
        print(f"   - {error}", file=sys.stderr)
    sys.exit(1)

print("✅ the default configuration is unchanged")
print(f"✅ the isolated configuration ({agent_id}) owns its project, networks, volumes,")
print(f"   images, domain and host port {port}")
PY