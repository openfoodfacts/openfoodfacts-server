#!/bin/bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Broad tracked inputs cover transitive Perl, translation and taxonomy dependencies.
# Keep docs and tests out so unrelated changes can reuse the same mappings.
source_hash=$(
  git ls-files -z -- \
    lib scripts conf po taxonomies data-default data ingredients packager-codes external-data \
    'Dockerfile*' docker docker-compose.yml env 'cpanfile*' Makefile .env \
    .github/scripts/producer_mappings_cache_key.sh .github/workflows/pull_request.yml \
    ':!:scripts/tests/**' \
    | LC_ALL=C sort -z | xargs -0 -r sha256sum -- | sha256sum | cut -d ' ' -f 1
)
printf 'producer-mappings-v1-%s-%s\n' "${RUNNER_OS:-$(uname -s)}" "$source_hash"
