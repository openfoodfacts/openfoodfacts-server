# Join the development

* Before you join the development, please set up the project on your local machine, run it and go through the application completely. Press on any button you can find and see where it leads to. Explore! You'll be more familiar with what is where and might even get some cool ideas on how to improve various aspects of the app.
* If you would like to work on an issue, drop in a comment at the issue. If it is already assigned to someone, but there is no sign of any work being done, please free to drop in a comment so that the issue can be assigned to you if the previous assignee has dropped it entirely.

## Contributing

[![Contribute with Gitpod](https://img.shields.io/badge/Contribute%20with-Gitpod-908a85?logo=gitpod)](https://gitpod.io/#https://github.com/openfoodfacts/openfoodfacts-server)

When contributing to this repository, please first discuss the change you wish to make via issue, or the official [Slack channel](https://openfoodfacts.slack.com/).


Get started running server in development mode, see [Dev environment quick start guide](./docs/dev/how-to-quick-start-guide.md)

### Pull Request Process

1. Ensure any install or build dependencies are removed before the end of the layer when doing a build.
2. Check that there are no conflicts and your request passes [Travis](https://travis-ci.org) build. Check the log of the pass test if it fails the build.
3. Give the description of the issue that you want to resolve in the pull request message.
   * The format of the commit message to be fixed is
     **fix:[Description of the issue] Fixes #[issue number]**
     Example: **fix: Add toast warning in `MainActivity.java` Fixes #529**
   * We are following [conventional commit](https://www.conventionalcommits.org/en/v1.0.0-beta.2/)
     with a [set of standard prefixes](https://github.com/commitizen/conventional-commit-types/blob/master/index.json)
     (`fix`, `feat`, `docs`, `build`, `test`…), ([full list for the server](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/.github/workflows/semantic-pr.yml))
     with the addition of:
     * `l10n` for translations
     * `taxonomy` for PR modifying a taxonomy
5. Wait for the maintainers to review your pull request and do the changes if requested.

## Contributions Best Practices

### Check before committing

You can save you sometime by running some checks locally before committing.

`make checks` should work.

### Commits

* Write clear meaningful git commit messages (Do read [here](https://chris.beams.io/posts/git-commit/)).
* Make sure your PR's description contains GitHub's special keyword references that automatically close the related issue when the PR is merged(For more info click [here](https://github.com/blog/1506-closing-issues-via-pull-requests)).
* When you make very, very minor changes to a PR of yours (like for example fixing a failing Travis build or some small style corrections or minor changes requested by reviewers) make sure you squash your commits afterward so that you don't have an absurd number of commits for a very small fix(Learn how to squash at [here](https://davidwalsh.name/squash-commits-git)).
* When you're submitting a PR for a UI-related issue, it would be really awesome if you add a screenshot of your change or a link to a deployment where it can be tested out along with your PR. It makes it very easy for the reviewers, and you'll also get reviews quicker.

### Feature Requests and Bug Reports

When you file a feature request or when you are submitting a bug report to the [issue tracker](https://github.com/openfoodfacts/openfoodfacts-server/issues), make sure you add steps to reproduce it. Especially if that bug is some weird/rare one.

## Contributing to the documentation

The documentation follows the [diataxis framework](https://diataxis.fr/) which is divided into four:

### Tutorials

They include lessons that take the reader by the hand through a series of steps to complete an implementation of the API.

### How To Guides

These are directions that guide the reader through the steps to achieve a specific end.

### References

The technical descriptions of the API including the OpenAPI schema are contained in this section. [Swagger](https://swagger.io/) and [Stoplight](https://stoplight.io/) are recommended OpenAPI tools you can use to render or edit the Open API schema.

### Explanations

They include discussion that clarifies and illuminates a particular topic when using the API.

<!-- Add links to docs for all the sections and make these sections more detailed -->

You can contribute to any of these sections by following these steps:

* Identify a problem and [create a new issue](https://github.com/openfoodfacts/openfoodfacts-server/issues/new) to describe the fix you will like to make. (if it hasnt been created).
* Optionally, you can join the [#api-documentation Slack Channel]( https://slack.openfoodfacts.org/) to discuss more about the task with the team and get more information to work with.
* Clone the project and work on a dedicated branch. Follow the [commits](#commits) guidelines to make your commit messages.
* Make a pull request. Be decriptive and make sure the pull request describes in detail the proposed changes.
* Wait for the maintainers to review your pull request and do the changes if requested.

## Code of Conduct

For our Code of Conduct, you should head over [here](https://wiki.openfoodfacts.org/Code_of_conduct).
