#!/usr/bin/env bash

# Always reconcile files and timing history; the matrix and Makefiles come from
# one plan. CI calls this only in its coordinator, never independently per shard.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 scripts/generate_matrix_config.py
