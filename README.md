<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-dark.png?refresh_github_cache=1">
  <source media="(prefers-color-scheme: light)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.png?refresh_github_cache=1">
  <img height="48" src="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.svg">
</picture>


# Open Food Facts - Product Opener (Web Server)

[![Project Status](http://opensource.box.com/badges/active.svg)](http://opensource.box.com/badges)
[![Crowdin](https://d322cqt584bo4o.cloudfront.net/openfoodfacts/localized.svg)](https://translate.openfoodfacts.org/)
[![Open Source Helpers](https://www.codetriage.com/openfoodfacts/openfoodfacts-server/badges/users.svg)](https://www.codetriage.com/openfoodfacts/openfoodfacts-server)
[![Backers on Open Collective](https://opencollective.com/openfoodfacts-server/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/openfoodfacts-server/sponsors/badge.svg)](#sponsors)

## Tests

[![Pull Requests](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/pull_request.yml/badge.svg)](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/pull_request.yml)

## What is Product Opener?

**Product Opener** is the server software for **Open Food Facts** and **Open Beauty Facts**. It is released under the AGPL license and is being developed in Perl, HTML and JavaScript as [Free and Open-Source Software](https://en.wikipedia.org/wiki/Free_and_open-source_software).

It works together with [Robotoff](https://github.com/openfoodfacts/robotoff), Open Food Facts' AI system (in Python, which can also be installed locally) and the [Open Food Facts apps](https://github.com/openfoodfacts/smooth-app) (which can work with your local instance after enabling dev mode)

## What is Open Food Facts?

### A food product database

Open Food Facts is a database of food products with ingredients, allergens, nutritional facts and all the tidbits of information that is available on various product labels.

### Made by everyone

Open Food Facts is a non-profit association of volunteers.
25.000+ contributors like you have added 1.7 million + products from 150 countries using our Android, iPhone or Windows Phone app or their camera to scan barcodes and upload pictures of products and their labels.

### For everyone

Data about food is of public interest and has to be open (i.e available to everyone). The complete database is published as open data and can be reused by anyone and for any use. Check-out the cool reuses or make your own!

* <https://world.openfoodfacts.org>

## Priorities

* [Top issues](https://github.com/openfoodfacts/openfoodfacts-server/issues/7374)
* [P1 problems](https://github.com/openfoodfacts/openfoodfacts-server/labels/P0,P1)
* [P1 candidates](https://github.com/openfoodfacts/openfoodfacts-server/labels/P1%20candidate)
* Please add roadmaps here

<!-- ## Libraries used -->

## How do I get started?

* Join us on Slack at <https://openfoodfacts.slack.com/> in the channels: `#api`, `#productopener`, `#dev`.
* Developer documentation:
   * [Quick start guide (Docker)](./docs/introduction/dev-environment-quick-start-guide.md)
   * [Developer guide (Docker)](./docs/how-to-guides/docker-developer-guide.md)
   * [Developer guide (Gitpod)](./docs/how-to-guides/use-gitpod.md)
   * Configuration [TBA]
   * Dependencies [TBA]
   * Database configuration [TBA]
   * How to run tests [TBA]
   * [Perl modules documentation (POD)](https://openfoodfacts.github.io/api-documentation/reference/perl/)

 * [API Documentation](https://openfoodfacts.github.io/api-documentation/)
 * [NEW API Documentation (WIP)](https//openfoodfacts.github.io/openfoodfacts-server/reference/api.html) ([source](./docs/reference/api.yml))

Note: documentation follows the [Diátaxis Framework](https://diataxis.fr/)

## Contribution guidelines

If you're new to Open-Source, we recommend you to check out our [_Contributing Guidelines_](https://github.com/openfoodfacts/openfoodfacts-server/blob/master/CONTRIBUTING.md). Feel free to fork the project and send us a pull request.

* Writing tests
* Code review
* Other guidelines
* Please add new features to the CHANGELOG.md file before or after merge to make testing easier

## Reporting problems or asking for a feature

Have a bug or a feature request? Please search for existing and closed issues. If your problem or idea is not addressed yet, please [open a new issue](https://github.com/openfoodfacts/openfoodfacts-server/issues). You can ask directly in the discussion room if you're not sure

## Translate Open Food Facts in your language

You can help translate the Open Food Facts web version and the app at :
<https://translate.openfoodfacts.org/> (no technical knowledge required, takes a minute to signup)

## Helping with HTML and CSS

We have [[templatized](https://github.com/openfoodfacts/openfoodfacts-server/tree/master/templates)] Product Opener, we use Gulp and NPM, but you'll need to run the Product Opener docker to be able to see the result (see the How do I get set up? section).

### Who do I talk to?

* Join our discussion room at <https://slack.openfoodfacts.org/> Make sure to join the #productopener and #productopener-alerts channels. Stéphane, Pierre, Charles or Hangy will be around to help you get started.

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/openfoodfacts/openfoodfacts-server/graphs/contributors"><img src="https://contrib.rocks/image?repo=openfoodfacts/openfoodfacts-server&columns=16" /></a>


## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/openfoodfacts-server#backer)]

<a href="https://opencollective.com/openfoodfacts-server#backers" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/backers.svg?width=890"></a>


## Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/openfoodfacts-server#sponsor)]

<a href="https://opencollective.com/openfoodfacts-server/sponsor/0/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/1/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/2/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/3/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/4/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/5/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/6/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/7/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/8/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/openfoodfacts-server/sponsor/9/website" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/sponsor/9/avatar.svg"></a>

<a href="https://nlnet.nl/"><img style="height:100px" src="https://static.openfoodfacts.org/images/misc/nlnet_logo.svg" alt="Logo NLnet: abstract logo of four people seen from above Logo NGI Zero: letterlogo shaped like a tag"></a>

Open Food Facts Personal Search project was funded through the <a href="https://nlnet.nl/discovery/">NGI0 Discovery</a> Fund,
a fund established by NLnet with financial support from the European Commission's <a href="https://ngi.eu">Next Generation Internet</a> programme.
