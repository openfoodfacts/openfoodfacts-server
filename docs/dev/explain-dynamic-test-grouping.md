# Dynamic Test Grouping

CI balances unit and integration test files using measured durations. Each run
creates one plan from the current checkout and shares it with every test shard.

## How groups are built

`scripts/dynamic_test_grouper.py` discovers every `.t` file under `tests/unit` or
`tests/integration` whenever a plan is generated. Added files enter that plan
immediately; deleted files and stale group assignments are discarded.

The default group count starts at six for unit tests and nine for integration
tests. It increases toward a 13-minute estimated load per group, with a maximum
of twelve groups, and never exceeds the number of files. An empty test directory
produces no groups. `--groups` overrides the automatic count for local use.

The greedy algorithm sorts files by estimated duration, then assigns each file
to the group with the smallest accumulated duration. Each file appears once,
and every generated group contains at least one file. Unknown durations use
30 seconds, configured by `DEFAULT_TEST_TIME`; `MAX_GROUP_TIME` sets the target.

Durations come from each file's enclosing Yath JUnit `testsuite`, including its
setup and teardown, rather than individual assertion times. Only known,
unambiguously matched files with valid durations and successful suites count.

Coverage and no-coverage timings are stored separately. Taxonomy-only PRs use
`no-coverage`; other PRs and main-branch unit runs use `coverage`. The
`no-coverage` history stays sparse, because few recent PRs are taxonomy-only. A
`no-coverage` plan therefore borrows the `coverage` timing for any file it has
not measured yet. Borrowed values are only used for planning and are never copied
into the `no-coverage` history.

## CI data flow

1. The matrix coordinator restores a versioned timing snapshot and generates
   `plan.json`, both group Makefiles, and the matrix together.
2. It uploads the Makefiles and plan as the run's `test-plan` artifact. Every
   shard downloads that exact plan instead of independently regenerating groups.
   The stable artifact name also works when only failed shards are rerun and
   the successful coordinator is left untouched.
3. Shards require the shared Makefiles and reject missing or empty groups.
   Successful test steps upload raw JUnit artifacts named by profile, test type,
   shard, and run attempt. They do not write timing caches.
4. Every Monday at 06:00 UTC, `test-groups-management.yml` runs trusted code from
   the default branch. It examines the ten most recent successful PR runs,
   including fork PRs, and downloads their timing artifacts as bounded ZIP/XML
   data in memory. It does not check out or execute PR code, or run another suite.
5. The collector uses each shard's latest available attempt and takes the median
   duration per known file across the collected samples. It retains existing
   known-file timings when no new sample is available, writes a new uniquely
   keyed default-branch snapshot, and publishes a report for both profiles.

The management workflow also supports manual dispatch on the default branch.
It does not create issues. Legacy unversioned timing caches are not restored.

## Generated files and history

| Path | Purpose |
| --- | --- |
| `.test_groups_cache/{unit,integration}_groups.json` | Generated groups; legacy tracked files still exist here. |
| `.test_groups_cache/{unit,integration}_groups.mk` | Makefile assignments; CI replaces the tracked copies with its shared plan. |
| `.test_groups_cache/plan.json` | Ignored runtime plan used by the coordinator. |
| `.test_timing_history/v2/{coverage,no-coverage}/{unit,integration}_timings.json` | Ignored runtime timing history restored from snapshots. |

Cached assignments are not reused by plan generation. Timing history influences
weights, while the current checkout always determines which files are assigned.

## Local use

The Python scripts use only the standard library. From the repository root:

```bash
# Print an automatically sized plan and its statistics.
uv run --no-project python scripts/dynamic_test_grouper.py --type=unit --profile=coverage

# Select a group count or the taxonomy-only timing profile.
uv run --no-project python scripts/dynamic_test_grouper.py --type=integration --groups=9 --profile=no-coverage

# Import local Yath results into one timing profile.
uv run --no-project python scripts/dynamic_test_grouper.py --type=unit --profile=coverage --update-timings --junit-dir=tests/unit/outputs

# Write the complete plan, Makefiles, and matrix configuration together.
TEST_TIMING_PROFILE=coverage ./.github/scripts/update_test_groups.sh

# Run a group using the generated Makefile assignments.
make unit_test_group TEST_GROUP=1
make integration_test_group TEST_GROUP=3

# Regenerate group files or remove the group directory.
make regenerate_test_groups
make clean_test_groups
```

`--force` remains accepted for existing callers, but script invocations already
build fresh groups. Regenerating files locally can modify the tracked group
JSON and Makefiles; inspect the diff before committing them. Cleaning the group
directory does not remove the separate timing history.

## Validation and limits

Run the focused regression suite with:

```bash
uv run --no-project python -m unittest discover -s scripts/tests -p 'test_*.py'
```

Local checks cover real Yath XML parsing, invalid artifacts, profile separation,
added and deleted files, complete plans, partial reruns, and the summary gate.
The complete artifact/cache flow has not yet been validated in GitHub Actions.

The 13-minute target is an estimate, not a job deadline. Unit shards run files
in parallel using `CPU_COUNT`, so summed file weights do not directly predict
wall time. Runner speed, coverage overhead, shared services, and setup outside
the measured suites also affect duration. Missing snapshots fall back to
30-second weights; the weekly sample window may not represent every test.
