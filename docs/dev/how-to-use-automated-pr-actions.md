# How to use automated pull request actions

We have github actions workflow that tries to help doing tedious tasks on pull-request. (see `pr_actions.yml`)

## (IMPORTANT) If you are on a PR from a fork

The actions will try to commit changes to your PR, with the openfoodfacts-bot user.
For this to happen you must let maintainers commit to your PR (see [github documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/allowing-changes-to-a-pull-request-branch-created-from-a-fork))

## Linting

We try to keep the same format on perl files and taxonomies.

Issue `/lint` in a comment on the PR, the linting actions will be launched in the background.

Of course you can also run `make lint` locally and commit changes. 

## Updating tests results

If you do a change that affects the API or HTML rendering, the tests might fail because they compare old stored results with newly generated one and find a difference.

Issue `/update_tests_results` in a comment to have the test refresh their expectation.

Beware that you must check for the changes after that to be sure, changes are correct and that you didn't introduce a bug.
