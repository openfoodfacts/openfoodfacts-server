#!/usr/bin/env bash
# perl-lsp via Docker for OpenCode / editors.
#
# Ports editors/claude-code/.lsp.json from
# https://github.com/tree-sitter-perl/perl-lsp to OpenCode, with one
# adaptation: the server runs inside the same backend image used by
# `make up`, so CPAN modules in PERL5LIB (/opt/perl/local/lib/perl5)
# resolve exactly like the running backend.
#
# Why docker run (not `docker compose exec backend`)?
# - `docker/dev.yml` mounts ./ to /opt/product-opener, so an exec-based
#   server would see /opt/product-opener/... URIs while OpenCode sends
#   host paths (/home/.../...). Paths would never match.
# - Here we mount the repo at the SAME absolute path inside and outside
#   (-v "$PROJECT_ROOT:$PROJECT_ROOT" -w "$PROJECT_ROOT"), so file:// URIs
#   match on both sides and perl-lsp's auto-discovery of lib/ works.
# - The image already contains /opt/perl/local/lib/perl5 (built from
#   cpanfile), so no host Perl setup is needed.
#
# Prerequisite: image exists (`make build` / `make up`). Images built from the
# current Dockerfile already contain perl-lsp in PATH; otherwise a host copy at
# .opencode/bin/perl-lsp (musl static release) is mounted in as a fallback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$PROJECT_ROOT/.opencode/bin/perl-lsp"

mkdir -p "$PROJECT_ROOT/.opencode/perl-lsp-cache"

IMAGE="${PERL_LSP_BACKEND_IMAGE:-openfoodfacts-server/backend:dev}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image $IMAGE not found. Run 'make build' (or 'make up') first." >&2
  exit 1
fi

# Prefer the perl-lsp baked into the image; fall back to the host copy.
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v perl-lsp' >/dev/null 2>&1; then
  MOUNT_ARGS=()
  ENTRYPOINT="perl-lsp"
elif [[ -x "$BIN" ]]; then
  MOUNT_ARGS=(-v "$BIN:/usr/local/bin/perl-lsp:ro")
  ENTRYPOINT="/usr/local/bin/perl-lsp"
else
  echo "perl-lsp not found in image $IMAGE and no host copy at $BIN" >&2
  echo "Either rebuild the image ('make build') or download a binary, e.g.:" >&2
  echo "  mkdir -p .opencode/bin && \\" >&2
  echo "  curl -fsSL https://github.com/tree-sitter-perl/perl-lsp/releases/download/v0.8.0/perl-lsp-x86_64-unknown-linux-musl.tar.gz \\" >&2
  echo "    -o /tmp/perl-lsp.tar.gz && tar -xzf /tmp/perl-lsp.tar.gz -C .opencode/bin && chmod +x .opencode/bin/perl-lsp" >&2
  exit 1
fi

exec docker run --rm -i \
  -v "$PROJECT_ROOT:$PROJECT_ROOT" \
  "${MOUNT_ARGS[@]}" \
  -v "$PROJECT_ROOT/.opencode/perl-lsp-cache:/var/www/.cache/perl-lsp" \
  -w "$PROJECT_ROOT" \
  -e "PERL5LIB=$PROJECT_ROOT/lib:/opt/perl/local/lib/perl5" \
  --entrypoint "$ENTRYPOINT" \
  "$IMAGE" "$@"
