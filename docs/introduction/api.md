# Open Food Facts API Documentation

Everything you need to know about Open Food Facts API.

## Overview

Open Food Facts is a food products database made by everyone, for everyone, that can help you make better food choices. Seeing it is open data, anyone can reuse it for any purpose. For example, you are building a nutrition app.
The Open Food Facts API enables developers to add to the products database and retrieve information about existing products. You may use the API to build applications allowing users to contribute to the database and make healthier food choices.
The current version of the API is `2`.

<!--- We can add a disclaimer image beside the next paragraph instead of making it a subheading -->

Data in the Open Food Facts database is provided voluntarily by users who want to support the program. As a result, there are no assurances that the data is accurate, complete, or reliable. The user assumes the entire risk of using the data.

## Environment

The OpenFoodFacts API has two environments.

- Production: <https://world.openfoodfacts.org>
- Staging: <https://world.openfoodfacts.net>

Consider using the [staging environment]( https://world.openfoodfacts.net) if you are not in a production scenario. While testing your applications, make all API requests to the staging environment. This way, we can ensure the product database is safe.

> **Warning**: The staging environment has an extra level of authentication (username: off, password: off). When making API requests to staging, you may use <https://off:off@world.openfoodfacts.net/> as the base URL to include the authentication.

## Authentication

All requests do not require authentication except for WRITE operations (Editing an Existing Product, Uploading images…).
<!---We may want to explain why -->
Create an account on the [Open Food Facts app](https://world.openfoodfacts.org/). Include your account credentials as parameters for authenticated requests where `user_id` is your username and `password` is your password.

To allow users of your app to contribute without registering individual accounts on the Open Food Facts website, you can create a global account. This way, we know that these contributions came from your application.

> The account you create in the production environment will only work for requests in production. You need to create an account in the [staging environment](https://world.openfoodfacts.net) if you want to make authenticated requests in staging.

<!--Add a section that links to the API reference docs -->

## Tutorials
<!--Have different categories of Tutorials and include the links in this session -->

## Help

- Try the FAQ - to answer most of your questions.
- Didn't get a satisfactory answer? Contact the Team on the #api [Slack Channel.](https://slack.openfoodfacts.org/)
- Report Bugs on the Open Food Facts Database.
- Do you have an issue or feature request? You can submit it here [here on GitHub](https://github.com/openfoodfacts/openfoodfacts-server/issues/new).
- Are you interested in contributing to this project? See your Contribution Guidelines.
 <!-- Embed contribution guideline link.-->

## SDKS

SDKs are available for specific languages to facilitate the usage of the API.

> **Warning**: The Open Food Facts API reference is the primary documentation source. Endeavor to read it before exploring any SDK.

<!--Add a link to the API reference -->

- [Cordova](https://github.com/openfoodfacts/openfoodfacts-cordova-app)
- [DART](https://github.com/openfoodfacts/openfoodfacts-dart/blob/master/DOCUMENTATION.md), Published on [pub.dev](https://pub.dev/packages/openfoodfacts)
- [Elixir](https://github.com/openfoodfacts/openfoodfacts-elixir)
- [Go](https://github.com/openfoodfacts/openfoodfacts-go)
- [NodeJS](https://github.com/openfoodfacts/openfoodfacts-nodejs)
- [PHP](https://github.com/openfoodfacts/openfoodfacts-php)
- [Laravel](https://github.com/openfoodfacts/openfoodfacts-laravel)
- [Python](https://github.com/openfoodfacts/openfoodfacts-python), Published on [pyipi](https://pypi.org/project/openfoodfacts/)
- [React Native](https://github.com/openfoodfacts/openfoodfacts-react-native)
- [Ruby](https://github.com/openfoodfacts/openfoodfacts-ruby)