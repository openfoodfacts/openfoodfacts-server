# Explain Dynamic Test Grouping System

This document describes the dynamic test grouping system that automatically optimizes test execution in CI by balancing test groups based on execution time and test count.

## Overview

The dynamic test grouping system replaces hardcoded test groups with an intelligent algorithm that:

- **Automatically discovers** all test files in the repository
- **Uses a greedy algorithm** to balance test execution times across groups
- **Caches results** to avoid unnecessary regeneration
- **Learns from execution data** to improve future groupings
- **Targets 10-13 minutes** execution time per group

## Architecture

### Core Components

1. **Dynamic Test Grouper** (`scripts/dynamic_test_grouper.py`)
   - Main script implementing the grouping algorithm
   - Handles caching, timing collection, and group generation

2. **Makefile Integration** 
   - Dynamic targets that replace hardcoded test groups
   - Automatic cache invalidation and regeneration

3. **CI Workflow Integration**
   - GitHub Actions steps for cache management
   - Automatic timing data collection
   - Performance monitoring and optimization

4. **Management Scripts**
   - Update script for CI environments
   - Performance analysis and reporting

### Algorithm Details

The system uses a **greedy bin-packing algorithm**:

```
1. Discover all test files automatically
2. Load historical timing data (if available)
3. Sort tests by execution time (descending)
4. For each test:
   - Find group with minimum total time
   - Assign test to that group
   - Update group's total time
5. Cache results for future use
```

## File Structure

```
.test_groups_cache/           # Cache directory (git-ignored)
├── unit_groups.json         # Cached unit test groups
├── unit_groups.mk          # Makefile format for unit groups
├── unit_timings.json       # Historical timing data for unit tests
├── integration_groups.json # Cached integration test groups
├── integration_groups.mk  # Makefile format for integration groups
└── integration_timings.json # Historical timing data for integration tests

scripts/
└── dynamic_test_grouper.py  # Main grouping algorithm

.github/
├── scripts/
│   └── update_test_groups.sh # CI update script
└── workflows/
    ├── pull_request.yml      # Updated CI workflow
    └── test-groups-management.yml # Management workflow
```

## Usage

### Manual Group Generation

```bash
# Generate unit test groups (6 groups)
python3 scripts/dynamic_test_grouper.py --type=unit --groups=6

# Generate integration test groups (9 groups)  
python3 scripts/dynamic_test_grouper.py --type=integration --groups=9

# Force regeneration (ignore cache)
python3 scripts/dynamic_test_grouper.py --type=unit --groups=6 --force

# Update timing data from JUnit results
python3 scripts/dynamic_test_grouper.py --type=unit --update-timings --junit-dir=tests/unit/outputs
```

### Makefile Targets

```bash
# Run a specific test group (uses dynamic groups)
make unit_test_group TEST_GROUP=1
make integration_test_group TEST_GROUP=3

# Force regenerate all groups
make regenerate_test_groups

# Clean cache
make clean_test_groups
```

### CI Integration

The system automatically:

1. **Checks for new tests** before each CI run
2. **Updates groups** if tests have been added/removed
3. **Collects timing data** after test execution
4. **Improves groupings** over time

## Configuration

### Target Execution Time

The default target is 10-13 minutes per group. To modify:

```python
# In scripts/dynamic_test_grouper.py
MAX_GROUP_TIME = 13 * 60  # 13 minutes in seconds
```

### Default Test Time

For new tests without timing data:

```python
# In scripts/dynamic_test_grouper.py
DEFAULT_TEST_TIME = 30    # 30 seconds
```

### Number of Groups

Configured in CI workflow and Makefile:

- **Unit tests**: 6 groups
- **Integration tests**: 9 groups

To change, update:
- `.github/workflows/pull_request.yml` (matrix strategy)
- Makefile calls to the grouper script

## Monitoring & Analysis

### Performance Reports

The system generates statistics showing:

```
# Group Statistics:
# Group 1: 12 tests, 8m 45s
# Group 2: 10 tests, 9m 12s
# Group 3: 11 tests, 8m 56s
# ...
# Max group time: 9.2m, Min: 8.7m, Avg: 9.0m
```

### Automated Monitoring

- **Weekly optimization runs** via GitHub Actions
- **Performance reports** generated as artifacts
- **Automatic issue creation** for balance problems

### Manual Analysis

```bash
# View current group statistics
./.github/scripts/update_test_groups.sh --stats

# Force regeneration with analysis
make regenerate_test_groups
```

## Troubleshooting

### Cache Issues

If groups seem incorrect:

```bash
# Clear cache and regenerate
make clean_test_groups
make regenerate_test_groups
```

### Missing Timing Data

For new repositories or after major changes:

```bash
# The system will use default times initially
# After first CI run, timing data will be collected automatically
```

### Group Imbalance

If groups exceed target time:

1. **Increase number of groups** in CI configuration
2. **Identify slow tests** for optimization
3. **Use the management workflow** for analysis

### CI Integration Issues

Check that:

1. **Cache keys** in CI workflow match current setup
2. **Python 3** is available in the CI environment
3. **File permissions** allow script execution

## Cache Invalidation

The cache is invalidated when:

1. **New tests are added** or existing tests removed
2. **Script is modified** (`dynamic_test_grouper.py`)
3. **Force regeneration** is requested
4. **Cache files are corrupted** or missing

## Performance Benefits

### Before (Hardcoded Groups)

- Manual group assignment
- Unbalanced execution times
- New tests forgotten in CI
- No optimization over time

### After (Dynamic Groups)

- Automatic test discovery
- Optimal load balancing
- Self-improving over time
- Target execution time control
- Zero maintenance required

## Development

### Adding New Features

To extend the system:

1. **Modify the Python script** for algorithm changes
2. **Update CI workflows** for new caching strategies
3. **Test with various scenarios** before deployment

### Algorithm Improvements

Possible enhancements:

- **Machine learning** for better time prediction
- **Dependency-aware grouping** for related tests
- **Dynamic group sizing** based on available runners
- **Test prioritization** for faster feedback

## Limitations

1. **Initial runs** use estimated times (30s default)
2. **Perl dependency** for the grouping script
3. **Cache storage** consumes some CI storage
4. **JUnit XML format** required for timing collection

## References

- [Bin Packing Algorithms](https://en.wikipedia.org/wiki/Bin_packing_problem)
- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [JUnit XML Format](https://github.com/testmoapp/junitxml)