# Ratchet Pinning in Open Food Facts CI/CD Workflows

## Introduction

This guide explains how to use Ratchet for pinning GitHub Actions references in Open Food Facts workflows. Ratchet is a tool that improves the security of CI/CD workflows by automating the process of pinning references to specific checksums rather than using mutable tags.

## Problem statement

Most CI/CD systems are one layer of indirection away from `curl | sudo bash`. Unless you are specifically pinning CI workflows, containers, and base images to checksummed versions, _everything_ is mutable: GitHub labels are mutable and Docker tags are mutable. This poses a substantial security and reliability risk.


##  Why Pin References?

When using GitHub Actions, most references look like this:

```yaml
uses: 'actions/checkout@v4'
# or
image: 'ubuntu:22.04'
```

These references are mutable, meaning the underlying code can change without changing the reference. This poses a security and reliability risk.

By pinning to specific checksums, you ensure your workflows use the exact same code every time:

```yaml
uses: 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683'
# or
image: 'ubuntu@sha256:47f14534bda344d9fe6ffd6effb95eefe579f4be0d508b7445cf77f61a0e5724'
```

Ratchet automates this pinning process while maintaining a record of the original constraint:

```yaml
uses: 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' # ratchet:actions/checkout@v4
```

## Installation

To use Ratchet with Open Food Facts, install it using one of these methods:

### macOS

```sh
brew install ratchet
```

### Linux/Windows/macOS (Binary)

Download from [GitHub Releases](https://github.com/sethvargo/ratchet/releases)

### Using Docker

```sh
docker run -it --rm -v "${PWD}:${PWD}" -w "${PWD}" ghcr.io/sethvargo/ratchet:latest
```

For convenience, create a shell alias:

```sh
function ratchet {
  docker run -it --rm -v "${PWD}:${PWD}" -w "${PWD}" ghcr.io/sethvargo/ratchet:latest "$@"
}
```

### Go Install

```sh
go install github.com/sethvargo/ratchet@latest
```

## Usage in Open Food Facts

### Pinning Workflow Files

To pin GitHub Action references in an Open Food Facts workflow file:

```sh
ratchet pin .github/workflows/my-workflow.yml
```

This will modify the file in place, adding pins to all references.

### Updating Pinned References

To update all references to the latest matching constraint:

```sh
ratchet update .github/workflows/my-workflow.yml
```

### Upgrading References

To upgrade all references to their latest available versions:

```sh
ratchet upgrade .github/workflows/my-workflow.yml
```

### Linting Workflow Files

To check if all references in a workflow file are properly pinned:

```sh
ratchet lint .github/workflows/my-workflow.yml
```

### Excluding References

Sometimes you may want to exclude specific references from being pinned (for example, references to internal actions or dynamic references). Add the `ratchet:exclude` comment:

```yaml
uses: 'openfoodfacts/some-action@develop' # ratchet:exclude
```

## Automated Pinning in CI

Open Food Facts uses automated pinning in the CI/CD pipeline. Here's how it works:

1. Pull requests are automatically checked to ensure all GitHub Actions references are pinned
2. If unpinned references are found, a workflow adds the pins and creates a comment on the PR

### Example Ratchet Workflow

```yaml
name: Ratchet Pin

on:
  pull_request:
    paths:
      - '.github/workflows/**'

jobs:
  ratchet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Run Ratchet
        uses: sethvargo/ratchet@v0.5.1
        with:
          files: .github/workflows/*.yml
          
      - name: Check for changes
        id: git-check
        run: |
          if [[ -n "$(git status --porcelain)" ]]; then
            echo "changes=true" >> $GITHUB_OUTPUT
          else
            echo "changes=false" >> $GITHUB_OUTPUT
          fi
          
      - name: Commit changes
        if: steps.git-check.outputs.changes == 'true'
        run: |
          git config --global user.name 'Ratchet Bot'
          git config --global user.email 'ratchet-bot@openfoodfacts.org'
          git commit -am "Pin GitHub Actions references with Ratchet"
          git push
```

## Best Practices for Open Food Facts Contributors

1. **Always pin new actions**: When adding a new GitHub Action to a workflow, use Ratchet to pin it immediately
   
2. **Regularly update pins**: Periodically update pinned references to get security updates:
   ```
   ratchet update .github/workflows/*.yml
   ```
   
3. **Verify before committing**: After pinning or updating, review the changes before committing

4. **Keep ratchet comments**: Don't remove the `# ratchet:...` comments as they're used for future updates

5. **Document excluded pins**: If you exclude a reference from pinning, add a comment explaining why

## Troubleshooting

### Authentication Issues

For private repositories or GitHub Enterprise, set the `GITHUB_TOKEN` environment variable:

```sh
export GITHUB_TOKEN=your_token
ratchet pin workflow.yml
```

### Handling Complex Workflows

Ratchet doesn't support dynamic references or YAML anchors. For dynamic references like:

```yaml
uses: 'actions/setup-node@${{ matrix.node-version }}'
```

Add the `ratchet:exclude` comment:

```yaml
uses: 'actions/setup-node@${{ matrix.node-version }}' # ratchet:exclude
```

## Additional Resources

- [Ratchet GitHub Repository](https://github.com/sethvargo/ratchet)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Open Food Facts GitHub Workflows](https://github.com/openfoodfacts/openfoodfacts-server/tree/main/.github/workflows)

## Questions or Issues?

If you have questions about using Ratchet in the Open Food Facts project, please reach out to the maintainers or open an issue on the repository.