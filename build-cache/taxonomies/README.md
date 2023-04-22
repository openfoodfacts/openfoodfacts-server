Cached copies of taxonomy build results are stored here.

If no local cache is available then https://github.com/openfoodfacts/openfoodfacts-build-cache is checked for a copy.

If the taxonomy needs to be built then this will be uploaded back to the repo if the GITHUB_TOKEN environment variable is set.

The token is a personal access token, created here: https://github.com/settings/tokens. Only the public_repo scope is needed.
