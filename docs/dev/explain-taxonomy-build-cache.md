# Explanation on Taxonomy Build Cache

Taxonomies have a significant impact on OFF processing and automated test results so need to be rebuilt before running any tests. However, this process takes some time, so the built taxonomy files are cached in a GitHub repository so that they only need to be rebuilt when there is a genuine change.

# How it works

A hash is calculated for all of the source files used to build a particular taxonomy and GitHub is then checked to see if a cache already exists for that hash.

If no cached build is found then the taxonomy is rebuilt and cached locally.

If the GITHUB_TOKEN environment variable is set then the cached build is also uploaded to the https://github.com/openfoodfacts/openfoodfacts-build-cache repository.

The token is a personal access token, created here: https://github.com/settings/tokens.
Only the public_repo scope is needed.

Note that no token is required to download previous cached builds from the repo.

# Storage

Cached copies of taxonomy build results are stored in `build-cache/taxonomies`.

If no local cache is available then https://github.com/openfoodfacts/openfoodfacts-build-cache is checked for a copy.


# Obtaining a token

The GITHUB_TOKEN is a personal access token, created here: https://github.com/settings/tokens. Only the public_repo scope is needed.

# Considerations

In maintaining this code be aware of the following complications...

## Circular Dependencies

There is a cicular dependency between taxonomies, languages and foods. The foods library is used to create the source for the nutrient_levels taxonomy, which uses transalations from languages. However, languages depends on the languages taxonomy...

This is currently resolved by building the taxonomy on the fly if it is requested but not currently built.

## Taxonomy Dependencies

Some taxonomies perform lookups on others, e.g. additives_classes are referenced by additives, so the referenced taxonomy needs to be built first. The build order is determined in the Config_off.pm file.
