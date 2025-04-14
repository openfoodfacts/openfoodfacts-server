<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-dark.png?refresh_github_cache=1">
  <source media="(prefers-color-scheme: light)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.png?refresh_github_cache=1">
  <img height="48" src="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.svg"/>
</picture>



([Looking for the Open Food Facts API doc ?](https://openfoodfacts.github.io/openfoodfacts-server/api/))

# Open Food Facts - Product Opener (Web Server)

[![Project Status](http://opensource.box.com/badges/active.svg)](http://opensource.box.com/badges)
[![Crowdin](https://d322cqt584bo4o.cloudfront.net/openfoodfacts/localized.svg)](https://translate.openfoodfacts.org/)
[![Open Source Helpers](https://www.codetriage.com/openfoodfacts/openfoodfacts-server/badges/users.svg)](https://www.codetriage.com/openfoodfacts/openfoodfacts-server)
[![Backers on Open Collective](https://opencollective.com/openfoodfacts-server/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/openfoodfacts-server/sponsors/badge.svg)](#sponsors)
![GitHub language count](https://img.shields.io/github/languages/count/openfoodfacts/openfoodfacts-server)
![GitHub top language](https://img.shields.io/github/languages/top/openfoodfacts/openfoodfacts-server)
![GitHub last commit](https://img.shields.io/github/last-commit/openfoodfacts/openfoodfacts-server)
![Github Repo Size](https://img.shields.io/github/repo-size/openfoodfacts/openfoodfacts-server)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/9345/badge)](https://www.bestpractices.dev/projects/9345)
[![DPG Badge](https://img.shields.io/badge/Verified-DPG%20(Since%20%202024)-3333AB?logo=data:image/svg%2bxml;base64,PHN2ZyB3aWR0aD0iMzEiIGhlaWdodD0iMzMiIHZpZXdCb3g9IjAgMCAzMSAzMyIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTE0LjIwMDggMjEuMzY3OEwxMC4xNzM2IDE4LjAxMjRMMTEuNTIxOSAxNi40MDAzTDEzLjk5MjggMTguNDU5TDE5LjYyNjkgMTIuMjExMUwyMS4xOTA5IDEzLjYxNkwxNC4yMDA4IDIxLjM2NzhaTTI0LjYyNDEgOS4zNTEyN0wyNC44MDcxIDMuMDcyOTdMMTguODgxIDUuMTg2NjJMMTUuMzMxNCAtMi4zMzA4MmUtMDVMMTEuNzgyMSA1LjE4NjYyTDUuODU2MDEgMy4wNzI5N0w2LjAzOTA2IDkuMzUxMjdMMCAxMS4xMTc3TDMuODQ1MjEgMTYuMDg5NUwwIDIxLjA2MTJMNi4wMzkwNiAyMi44Mjc3TDUuODU2MDEgMjkuMTA2TDExLjc4MjEgMjYuOTkyM0wxNS4zMzE0IDMyLjE3OUwxOC44ODEgMjYuOTkyM0wyNC44MDcxIDI5LjEwNkwyNC42MjQxIDIyLjgyNzdMMzAuNjYzMSAyMS4wNjEyTDI2LjgxNzYgMTYuMDg5NUwzMC42NjMxIDExLjExNzdMMjQuNjI0MSA5LjM1MTI3WiIgZmlsbD0id2hpdGUiLz4KPC9zdmc+Cg==)](https://www.digitalpublicgoods.net/r/open-food-facts)

## Tests

[![Pull Requests](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/pull_request.yml/badge.svg)](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/pull_request.yml)

## What is Product Opener?

**Product Opener** is the server software for **Open Food Facts** and **Open Beauty Facts**. It is released under the AGPL license and is being developed in Perl, HTML and JavaScript as [Free and Open-Source Software](https://en.wikipedia.org/wiki/Free_and_open-source_software).

It works together with [Robotoff](https://github.com/openfoodfacts/robotoff), Open Food Facts' AI system (in Python, which can also be installed locally) and the [Open Food Facts App](https://github.com/openfoodfacts/smooth-app) (which can work with your local instance after enabling dev mode), as well as Open Food Facts query and the upcoming openfoodfacts-auth. For a full architecture diagram, please read https://github.com/openfoodfacts
<br><br>
## What is Open Food Facts?

### A food product database

Open Food Facts is a database of food products with ingredients, allergens, nutritional facts and all the tidbits of information that is available on various product labels.

### Made by everyone

Open Food Facts is a non-profit association of volunteers. 25,000+ contributors like you have added 1.7 million+ products from 150 countries using our Android, iPhone and Windows Phone apps or their camera to scan barcodes and upload pictures of products and their labels.

### For everyone

Data about food is of public interest and has to be open (i.e available to everyone). The complete database is published as open data and can be reused by anyone and for any use. Check-out the cool reuses or make your own!


Visit the [website](https://world.openfoodfacts.org) for more info.
<br><br>
## 🎨 Design & User interface
- We strive to thoughfully design every feature before we move on to implementation, so that we respect Open Food Facts' graphic charter and nascent design system, while having efficient user flows.
- [![Figma](https://img.shields.io/badge/figma-%23F24E1E.svg?logo=figma&logoColor=white) Mockups on the current app and future plans to discuss](https://www.figma.com/design/Qg9URUyrjHgYmnDHXRsTTB/Current-Website-design?m=auto&t=jNwvjRR8nIgOzzJZ-6)
<br><br>
## Weekly Meetings

- We e-meet on Mondays at 17:00 Paris Time (Europe/Paris), which is CET (UTC+1) or CEST (UTC+2 during Daylight Saving Time). For easy conversion in local time, check [17:00 in Paris](https://time.is/1700_in_Paris).
- ![Google Meet](https://img.shields.io/badge/Google%20Meet-00897B?logo=google-meet&logoColor=white) Video call link: https://meet.google.com/nnw-qswu-hza
- Join by phone: https://tel.meet/nnw-qswu-hza?pin=2111028061202
- Add the event to your calendar by [adding the Open Food Facts community calendar to your calendar](https://wiki.openfoodfacts.org/Events).
- [Weekly agenda](https://drive.google.com/open?id=1LL8-aiSF482xaJ1o0AKmhXB5QWfVE0_jzvYakq3VXys): please add the Agenda items as early as you can.
- Make sure to check the agenda items in advance of the meeting, so that we have the most informed discussions possible.
- The meeting will handle agenda items first, and if time permits, collaborative bug triage.
- We strive to timebox the core of the meeting (decision making) to 30 minutes, with an optional free discussion/live debugging afterwards.
- We take comprehensive notes in the weekly agenda of agenda item discussions and of decisions taken.
<br><br>
## Feature Sprint
- We use feature-based sprints, [tracked here](https://github.com/orgs/openfoodfacts/projects/32)
<br><br>
## User Interface
-  [![Figma](https://img.shields.io/badge/figma-%23F24E1E.svg?logo=figma&logoColor=white) Mockups on the current design and future plans to discuss](https://www.figma.com/file/Qg9URUyrjHgYmnDHXRsTTB/New-website-design-(2022)-(Quentin)?t=00ZMlgxe590W8TRY-0)
<br><br>
## Priorities
- [Top issues](https://github.com/openfoodfacts/openfoodfacts-server/issues/7374)
- [P1 problems](https://github.com/openfoodfacts/openfoodfacts-server/issues?q=is%3Aopen%20label%3A%22%F0%9F%8E%AF%20P0%22%20OR%20label%3A%22%F0%9F%8E%AF%20P1%22%20)
- [P1 candidates](https://github.com/openfoodfacts/openfoodfacts-server/issues?q=is%3Aopen%20label%3A%22%F0%9F%8E%AF%20P1%20candidate%22%20)
<br><br>
## How do I get started?
- Join us on slack at <https://openfoodfacts.slack.com/> in the channels: `#api`, `#productopener`, `#dev`.
- Open Food Facts API documentation:
  - [Introduction to the API](https://openfoodfacts.github.io/openfoodfacts-server/api/)
  - [Full reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/) ([source](https://github.com/openfoodfacts/openfoodfacts-server/tree/main/docs/api/ref/api.yml))
- Developer documentation:
  - To start coding, head to the [Quick start guide (docker)](./docs/dev/how-to-quick-start-guide.md)
  - Additional documentation
    - [Server documentation](https://openfoodfacts.github.io/openfoodfacts-server/)
    - [Developer guide (docker)](./docs/dev/how-to-develop-using-docker.md)
    - [Developer guide (gitpod)](./docs/dev/how-to-use-gitpod.md)
    - Configuration [TBA]
    - Dependencies [TBA]
    - Database configuration [TBA]
    - How to run tests [TBA]
    - [Perl modules documentation (POD)](https://openfoodfacts.github.io/dev/ref-perl/)


**Note:** Documentation follows the [Diátaxis Framework](https://diataxis.fr/).
<br><br>
## Contribution Guidelines

If you're new to Open-Source, we recommend you to check out our [_Contributing Guidelines_](https://github.com/openfoodfacts/openfoodfacts-server/blob/master/CONTRIBUTING.md). Feel free to fork the project and send us a pull request.

- Writing tests
- Code review

Please add new features to the `CHANGELOG.md` file before or after merge to make testing easier
<br><br>
## Reporting problems or asking for a feature

Have a bug or a feature request? Please search for existing and closed issues. If your problem or idea is not addressed yet, please [open a new issue](https://github.com/openfoodfacts/openfoodfacts-server/issues). You can ask directly in the discussion room if you're not sure.
<br><br>
## Translate Open Food Facts in your language

You can help translate the Open Food Facts web version and the app at:
<https://translate.openfoodfacts.org/> (no technical knowledge required, takes a minute to signup).
<br><br>
## Helping with HTML and CSS

We have [templatized](https://github.com/openfoodfacts/openfoodfacts-server/tree/master/templates) Product Opener, we use Gulp and NPM, but you'll need to run the Product Opener docker to be able to see the result (see the How do I get set started? section).
In particular, you can [help with issues on the new design](https://github.com/openfoodfacts/openfoodfacts-server/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22%F0%9F%8E%A8%20New%20design%22).
<br><br>
## Who do I talk to?

Join our discussion room at <https://slack.openfoodfacts.org/>. Make sure to join the `#productopener` and `#productopener-alerts` channels. Stéphane, Pierre, Charles or Hangy will be around to help you get started.
<br><br>
## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/openfoodfacts/openfoodfacts-server/graphs/contributors"><img src="https://contrib.rocks/image?repo=openfoodfacts/openfoodfacts-server&columns=16" /></a>
<br><br>
## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/openfoodfacts-server#backer)]

<a href="https://opencollective.com/openfoodfacts-server#backers" target="_blank"><img src="https://opencollective.com/openfoodfacts-server/backers.svg?width=890"></a>
<br><br>
## Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [Become a sponsor](https://opencollective.com/openfoodfacts-server#sponsor)

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

---

<div align="center">

<br />
<a href="https://www.digitalpublicgoods.net/r/open-food-facts" target="_blank" rel="noopener noreferrer"><img src="https://github.com/DPGAlliance/dpg-resources/blob/main/docs/assets/dpg-badge.png?raw=true" width="100" alt="Digital Public Goods Badge"></a>

</div>
