# How to manage SDK notifications for API changes

Open Food Facts Server includes an automated workflow that notifies SDK maintainers when API changes are released.

## Overview

The [API Change Notifications workflow](../../.github/workflows/api-change-notifications.yml) automatically creates issues in SDK repositories when a release contains API changes documented in the [API and Product Schema Change Log](../api/ref-api-and-product-schema-change-log.md).

## How it works

### Trigger
The workflow triggers automatically when:
- A new release is published in the main repository
- The release contains modifications to `docs/api/ref-api-and-product-schema-change-log.md`

### Detection Logic
The workflow:
1. Compares the API changelog between the current release and the previous release
2. Looks for changes indicating API modifications:
   - New version entries (e.g., `### 2025-06-11 - Product version 1002`)
   - Breaking changes sections
   - API version updates

### Notification Process
When API changes are detected, the workflow:
1. Creates standardized issues in all SDK repositories
2. Includes release information and change summary
3. Provides links to documentation and resources
4. Tracks success/failure for each repository

## Supported SDK Repositories

The workflow notifies the following SDK repositories:
- [openfoodfacts/openfoodfacts-php](https://github.com/openfoodfacts/openfoodfacts-php)
- [openfoodfacts/openfoodfacts-js](https://github.com/openfoodfacts/openfoodfacts-js)
- [openfoodfacts/openfoodfacts-laravel](https://github.com/openfoodfacts/openfoodfacts-laravel)
- [openfoodfacts/openfoodfacts-python](https://github.com/openfoodfacts/openfoodfacts-python)
- [openfoodfacts/openfoodfacts-ruby](https://github.com/openfoodfacts/openfoodfacts-ruby)
- [openfoodfacts/openfoodfacts-java](https://github.com/openfoodfacts/openfoodfacts-java)
- [openfoodfacts/openfoodfacts-elixir](https://github.com/openfoodfacts/openfoodfacts-elixir)
- [openfoodfacts/openfoodfacts-dart](https://github.com/openfoodfacts/openfoodfacts-dart)
- [openfoodfacts/openfoodfacts-go](https://github.com/openfoodfacts/openfoodfacts-go)

## Issue Template

Created issues include:
- 🚨 Clear title indicating API changes and required SDK updates
- Release information with links
- Summary of detected API changes
- Action items for SDK maintainers
- Links to documentation and support channels
- Automatic labeling with `api-change` and `needs-update`

## Monitoring and Troubleshooting

### Workflow Logs
Monitor the workflow execution in the [Actions tab](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/api-change-notifications.yml).

### Common Issues
- **Repository access errors**: Some SDK repositories may have different permission settings
- **API parsing issues**: Changes to the changelog format may affect detection
- **Rate limiting**: GitHub API limits may affect bulk issue creation

The workflow includes error handling and will continue even if some repositories are inaccessible.

### Manual Trigger
If needed, you can manually create issues for SDK repositories:
1. Review the [API changelog](../api/ref-api-and-product-schema-change-log.md)
2. Use the issue template from the workflow
3. Create issues manually in affected SDK repositories

## Maintenance

### Adding New SDK Repositories
To add a new SDK repository to notifications:
1. Edit the `SDK_REPOS` array in `.github/workflows/api-change-notifications.yml`
2. Add the repository in format `"openfoodfacts/repository-name"`
3. Test the workflow with a test release

### Updating Issue Template
The issue template can be customized by modifying the `ISSUE_BODY` variable in the workflow file.

### Permissions
The workflow uses the `GITHUB_TOKEN` with permissions to:
- Read repository contents
- Create issues in target repositories

Ensure the token has appropriate cross-repository permissions for issue creation.