# Automated Dependency Updates (Future Enhancement)

This document outlines a potential GitHub Actions workflow to automatically update `cpanfile.snapshot` with newer dependency versions.

## Why Automated Updates?

While Dependabot doesn't support CPAN packages, we can create our own automation to:
- Check for updates to Perl dependencies periodically
- Generate a new `cpanfile.snapshot` with updated versions
- Create a pull request for review
- Run tests to ensure compatibility

## Proposed Workflow

Here's a template for a GitHub Actions workflow that could be implemented:

```yaml
name: Update Perl Dependencies

on:
  schedule:
    # Run monthly on the 1st at 9:00 AM UTC
    - cron: '0 9 1 * *'
  workflow_dispatch: # Allow manual triggers

jobs:
  update-dependencies:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Remove existing snapshot
        run: rm -f cpanfile.snapshot
      
      - name: Generate new snapshot with latest versions
        run: ./scripts/generate_cpanfile_snapshot.sh
      
      - name: Check if snapshot changed
        id: check-changes
        run: |
          if git diff --quiet cpanfile.snapshot; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
          fi
      
      - name: Create Pull Request
        if: steps.check-changes.outputs.changed == 'true'
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: 'chore: update Perl dependencies in cpanfile.snapshot'
          title: 'Update Perl Dependencies'
          body: |
            This automated PR updates the Perl dependencies to their latest compatible versions.
            
            ## Changes
            - Updated `cpanfile.snapshot` with newer dependency versions
            - All constraints in `cpanfile` are respected
            
            ## Testing
            Please review the changes and ensure:
            - [ ] All tests pass
            - [ ] No breaking changes in updated dependencies
            - [ ] The build completes successfully
            
            ## Security
            Check for security vulnerabilities in updated dependencies using:
            ```bash
            # Manual review of changes
            git diff main...HEAD cpanfile.snapshot
            ```
            
            Generated automatically by the Update Perl Dependencies workflow.
          branch: automated/update-perl-dependencies
          delete-branch: true
          labels: dependencies, automated
```

## Benefits

1. **Regular Updates**: Dependencies are kept reasonably up-to-date
2. **Security Patches**: Get security fixes in a timely manner
3. **Controlled Updates**: Changes come as PRs that can be reviewed
4. **Test Integration**: CI tests run automatically on the PR
5. **No Manual Work**: Reduces maintenance burden

## Considerations

### Update Frequency

- **Monthly**: Good balance between staying current and avoiding churn
- **Quarterly**: More conservative, fewer updates to review
- **On-Demand**: Manual trigger when needed (via `workflow_dispatch`)

### Version Constraints

The workflow respects all version constraints in `cpanfile`:
- `requires 'Module', '>= 1.0'` - will update to latest >= 1.0
- `requires 'Module', '< 2.0'` - will update but stay below 2.0
- `requires 'Module', '== 1.5'` - will not update (pinned version)

### Breaking Changes

Some updates may introduce breaking changes:
- The PR should always be reviewed before merging
- Tests help catch compatibility issues
- Can add additional checks (like Perl::Critic) to the workflow

## Implementation Steps

To enable automated updates:

1. Create `.github/workflows/update-perl-dependencies.yml` with the content above
2. Test the workflow manually using the workflow_dispatch trigger
3. Review and adjust the schedule to your needs
4. Consider adding notifications (Slack, email) when updates are available
5. Add a CHANGELOG entry generation step

## Advanced Features

Could be added in the future:

### Dependency Vulnerability Scanning

```yaml
- name: Check for vulnerabilities
  run: |
    # Use cpan-audit or similar tool
    cpanm --quiet App::cpanoutdated
    cpan-outdated --verbose | tee outdated.txt
```

### Version Diff Summary

```yaml
- name: Generate update summary
  run: |
    git diff cpanfile.snapshot | grep -E "^\+|^\-" | \
      grep -v "^\+\+\+\|^\-\-\-" > changes.diff
    echo "## Dependency Changes" >> $GITHUB_STEP_SUMMARY
    cat changes.diff >> $GITHUB_STEP_SUMMARY
```

### Selective Updates

```yaml
- name: Update only security fixes
  run: |
    # Custom logic to identify and update only security patches
    # This would require integration with security advisories
```

## Security Considerations

- The workflow needs write access to create PRs
- Consider using a bot account or service account
- Review permissions carefully
- Enable branch protection rules to prevent auto-merging

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Create Pull Request Action](https://github.com/peter-evans/create-pull-request)
- [Carton Documentation](https://metacpan.org/pod/Carton)
- [cpanfile Documentation](https://metacpan.org/pod/cpanfile)
