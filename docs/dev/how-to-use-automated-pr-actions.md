# How to use automated pull request actions

We have a github actions workflow that tries to help with tedious tasks on pull requests (see `pr_actions.yml`).

## (IMPORTANT) If you are on a PR from a fork

The actions will try to commit changes to your PR as the openfoodfacts-bot user.
For this to happen you must let maintainers commit to your PR (see [github documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/allowing-changes-to-a-pull-request-branch-created-from-a-fork)).

## Linting

We try to keep the same format for perl files and taxonomies.

Enter `/lint` in a comment on the PR; the linting actions will be launched in the background.

Of course you can also run `make lint` locally and commit changes. 

## Updating tests results

If you make a change that affects the API or HTML rendering, the tests may fail because they compare old stored results with the newly generated one and find a difference.

Enter `/update_tests_results` in a comment to have the tests refresh their expectations.

Be careful to check the changes after that, to make sure they are correct and you didn't introduce a bug.

## Troubleshooting

Normally, after the action finishes, it commits to your PR and it restarts the checks.

If that does not happen, you can see the result of actions in the actions tab, [selecting the pr_actions workflow](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/pr_actions.yml)
