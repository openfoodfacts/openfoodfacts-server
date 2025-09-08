# Documentation Sync Setup

This repository includes a GitHub workflow that automatically syncs documentation from the `/docs` directory to the [openfoodfacts-documentation](https://github.com/openfoodfacts/openfoodfacts-documentation) repository using the fumadocs-transpiler.

## How it works

The workflow (`sync-docs-to-fumadocs.yml`) automatically:

1. **Triggers** on pushes to the `main` branch when files in the `/docs` directory change
2. **Converts** all `.md` files to `.mdx` format using [fumadocs-transpiler](https://www.npmjs.com/package/fumadocs-transpiler)
3. **Organizes** the converted files in the `content/docs/Product-Opener` directory of the documentation repository
4. **Adds** proper frontmatter and navigation metadata for Fumadocs
5. **Fixes** relative links to work with the Fumadocs structure
6. **Commits** and pushes the changes to the documentation repository

## Required Setup

### GitHub Secret Configuration

For the workflow to function, you need to set up a GitHub secret:

1. **Create a Personal Access Token (PAT)**:
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate a new token with the following permissions:
     - `repo` (Full control of private repositories)
     - `public_repo` (Access public repositories)

2. **Add the secret to this repository**:
   - Go to this repository's Settings → Secrets and variables → Actions
   - Add a new repository secret:
     - **Name**: `DOCUMENTATION_REPO_TOKEN`
     - **Value**: The PAT you created above

### Dependencies

The workflow automatically installs the required dependency:
- `fumadocs-transpiler` - Converts markdown to MDX format compatible with Fumadocs

## File Structure

After conversion, the documentation will be organized as follows in the documentation repository:

```
content/docs/Product-Opener/
├── index.mdx                 # Main documentation index
├── meta.json                 # Navigation metadata
├── api/
│   ├── meta.json            # API section metadata
│   └── *.mdx                # API documentation files
├── dev/
│   ├── meta.json            # Developer section metadata
│   └── *.mdx                # Developer documentation files
└── tutorials/
    └── *.mdx                # Tutorial files
```

## Features

### Automatic Frontmatter Generation
The workflow automatically adds frontmatter to MDX files:
```yaml
---
title: "Page Title"
description: "Page description"
---
```

### Link Fixing
Relative links are automatically updated to work with the Fumadocs structure:
- `./page.md` → `/docs/Product-Opener/page`
- `../other.md` → `/docs/Product-Opener/other`

### Navigation Metadata
The workflow creates `meta.json` files for proper navigation in Fumadocs.

## Manual Testing

To test the conversion locally:

```bash
# Install dependencies
npm install

# Convert a single file
npx fumadocs-transpiler docs/index.md -o output/index.mdx

# Convert multiple files
find docs -name "*.md" -exec npx fumadocs-transpiler {} -o output/{} \;
```

## Troubleshooting

1. **Workflow fails with authentication error**: Check that the `DOCUMENTATION_REPO_TOKEN` secret is set correctly
2. **Conversion errors**: Check the fumadocs-transpiler logs in the workflow output
3. **Missing files**: Ensure the source `.md` files are in the `/docs` directory

## Contributing

When making changes to documentation:
1. Edit the `.md` files in the `/docs` directory
2. Commit and push to the `main` branch
3. The workflow will automatically sync changes to the documentation repository
