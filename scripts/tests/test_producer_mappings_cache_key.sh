#!/bin/bash
set -euo pipefail

key_script="$(cd "$(dirname "$0")/../../.github/scripts" && pwd)/producer_mappings_cache_key.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cd "$fixture"
git init -q

inputs=(
  lib/ProductOpener/Producers.pm scripts/build_lang.pl conf/options.json po/fr.po
  taxonomies/languages.txt data-default/fields.json data/fields.txt ingredients/fields.txt
  packager-codes/fields.csv external-data/fields.txt Dockerfile docker/dev.yml docker-compose.yml
  env/env.off cpanfile cpanfile.snapshot Makefile .env
  .github/scripts/producer_mappings_cache_key.sh .github/workflows/pull_request.yml
)
for path in "${inputs[@]}" docs/ci.md tests/unit/producers.t scripts/tests/check.t; do
  mkdir -p "$(dirname "$path")"
  printf 'original\n' > "$path"
done
git add --force .
baseline=$(bash "$key_script")
[[ $baseline == producer-mappings-v1-* ]]

for path in "${inputs[@]}"; do
  printf 'changed\n' > "$path"
  [[ $(bash "$key_script") != "$baseline" ]] || { echo "Input missing from key: $path" >&2; exit 1; }
  printf 'original\n' > "$path"
done
for path in docs/ci.md tests/unit/producers.t scripts/tests/check.t; do
  printf 'changed\n' > "$path"
done
[[ $(bash "$key_script") == "$baseline" ]] || { echo 'Docs/tests changed the key' >&2; exit 1; }

git mv lib/ProductOpener/Producers.pm lib/ProductOpener/NewProducers.pm
[[ $(bash "$key_script") != "$baseline" ]] || { echo 'Renaming an input did not change the key' >&2; exit 1; }
git mv lib/ProductOpener/NewProducers.pm lib/ProductOpener/Producers.pm
git rm -q -f conf/options.json
[[ $(bash "$key_script") != "$baseline" ]] || { echo 'Removing an input did not change the key' >&2; exit 1; }

echo 'Producer mappings key tests passed (20 input paths, unrelated docs/tests, rename, deletion).'
