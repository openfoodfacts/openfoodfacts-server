#!/usr/bin/env bash
# perltidy via Docker for editors (e.g. kaktus.perltidy-more).
#
# Runs the same perltidy (same version, same .perltidyrc) as the backend image
# used by `make up` / `make check_perltidy`, so editor formatting never drifts
# from CI. The repo is mounted at the SAME absolute path inside and outside the
# container, so an absolute --profile path means the same file on both sides.
#
# Prerequisite: image exists (`make build` / `make up`). perltidy is baked
# into the image (cpanfile develop section) — nothing to install on the host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE="${PERL_LSP_BACKEND_IMAGE:-openfoodfacts-server/backend:dev}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image $IMAGE not found. Run 'make build' (or 'make up') first." >&2
  exit 1
fi

exec docker run --rm -i \
  -v "$PROJECT_ROOT:$PROJECT_ROOT" \
  -w "$PROJECT_ROOT" \
  --entrypoint perltidy \
  "$IMAGE" "$@"
