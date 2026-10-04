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
            "$REPO_ROOT/scripts/dev-agent-env.sh" >/dev/null 2>&1
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
mapfile -t COORD_PORTS < <(
    for entry in "$COORD/cache/off-agents"/*; do
        case "$(basename "$entry")" in
            .port-*) continue ;;
        esac
        sed -n 1p "$entry"
    done
)

[ "${#COORD_IDS[@]}" -eq 5 ] ||
    fail "expected 5 registered worktrees, got ${#COORD_IDS[@]}: ${COORD_IDS[*]}"
[ "$(printf '%s\n' "${COORD_IDS[@]}" | sort -u | grep -c .)" -eq 5 ] ||
    fail "two worktrees got the same id: ${COORD_IDS[*]}"
[ "$(printf '%s\n' "${COORD_PORTS[@]}" | sort -u | grep -c .)" -eq 5 ] ||
    fail "two worktrees got the same port: ${COORD_PORTS[*]}"
for port in "${COORD_PORTS[@]}"; do
    [ -n "$port" ] || fail "a worktree was registered without a port: ${COORD_IDS[*]}"
done
echo "✅ concurrent worktrees derive distinct ids and ports without coordinating"

# 1. the generator, exactly as `make agent` invokes it
make --no-print-directory ENVRC="$WORK_DIR/envrc" agent ID="$AGENT_ID" PORT="$AGENT_PORT" >/dev/null

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

# An id that belongs to another worktree must be refused, not silently shared.
OTHER="$WORK_DIR/other"
mkdir -p "$OTHER"
STOLEN_ID="${COORD_IDS[0]}"
if XDG_CACHE_HOME="$COORD/cache" ENVRC="$OTHER/.envrc" \
    ./scripts/dev-agent-env.sh --id "$STOLEN_ID" >/dev/null 2>&1; then
    fail "claiming id '$STOLEN_ID' owned by another worktree should have failed"
fi
echo "✅ an id owned by another worktree is refused"

# 2. the Makefile derivation. We point ENVRC at the generated file rather than at
# .envrc: make includes it after .env, and an assignment in a makefile always beats
# an inherited environment variable, so a shell export cannot override .env.
effective="$(make --no-print-directory ENVRC="$WORK_DIR/envrc" print-agent-config)"

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
AGENT_VALUES="$(tr '\n' ' ' <<<"$effective")"
DEFAULT_JSON="$(COMPOSE_FILE="$COMPOSE_FILES" docker compose --env-file=.env config --format json)"
AGENT_JSON="$(env $AGENT_VALUES COMPOSE_FILE="$COMPOSE_FILES" \
    docker compose --env-file=.env config --format json)"

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