# Open Food Facts API Documentation

Everything you need to know about Open Food Facts API.

## Overview

Open Food Facts is a food products database made by everyone, for everyone, that can help you make better food choices. Seeing it is open data, anyone can reuse it for any purpose. For example, you are building a nutrition app.
The Open Food Facts API enables developers to add to the products database and retrieve information about existing products. You may use the API to build applications allowing users to contribute to the database and make healthier food choices.
The current version of the API is `2`.

<!--- We can add a disclaimer image beside the next paragraph instead of making it a subheading -->

Data in the Open Food Facts database is provided voluntarily by users who want to support the program. As a result, there are no assurances that the data is accurate, complete, or reliable. The user assumes the entire risk of using the data.

## Before You Start

The Open Food Facts database is available under the [Open Database License](https://opendatacommons.org/licenses/odbl/1.0/). The individual contents of the database are available under the [Database Contents License](https://opendatacommons.org/licenses/dbcl/1.0/).
Product images are available under the [Creative Commons Attribution ShareAlike](https://creativecommons.org/licenses/by-sa/3.0/deed.en) license. They may contain graphical elements subject to copyright or other rights that may, in some cases, be reproduced (quotation rights or fair use).

Please read the [Terms and conditions of use and reuse](https://world.openfoodfacts.org/terms-of-use) before reusing the data.

We are interested in learning what the Open Food Facts data is used for. It is not mandatory, but we would very much appreciate it if you [tell us about your reuses](mailto:contact@openfoodfacts.org) so that we can share them with the Open Food Facts community.

## How to Best Use the API

### General principles

- You can search for product information, including many useful computed values.
- If you can't get the information on a specific product, you can get your user to send photos and data that will then be processed by Open Food Facts AI and contributors to get the computed result you want to show them.
- You can also implement the complete flow so that they immediately get the result with some effort on their side.

### If your users do not expect a result immediately (e.g., Inventory apps)

- Submit photos (front/nutrition/ingredients): the most painless thing for your users
- The Open Food Facts AI Robotoff will generate some derived data from the photos.
- Over time, other apps and the Open Food Facts community will fill the data gaps.

### If your users expect a result immediately (e.g., Nutrition apps)

- Submit nutrition facts + category > get Nutri-Score
- Submit ingredients > get the NOVA group (about food ultra-processing), additives, allergens, normalized ingredients, vegan, vegetarian…
- Submit category + labels > soon get the Eco-Score (about environmental impact)

## Environment

The OpenFoodFacts API has two environments.

- Production: <https://world.openfoodfacts.org>
- Staging: <https://world.openfoodfacts.net>

Consider using the [staging environment]( https://world.openfoodfacts.net) if you are not in a production scenario. While testing your applications, make all API requests to the staging environment. This way, we can ensure the product database is safe.

> **Warning**: The staging environment has an extra level of authentication (username: off, password: off). When making API requests to staging, you may use <https://off:off@world.openfoodfacts.net/> as the base URL to include the authentication.

## Authentication

All requests do not require authentication except for WRITE operations (Editing an Existing Product, Uploading images…).
<!---We may want to explain why -->
Create an account on the [Open Food Facts app](https://world.openfoodfacts.org/). You then have to alternative:

- The preferred one:
  use the login API to get a session cookie and use this cookie in your subsequent request to be authenticated.
  Note however that the session must always be used from the same IP address, and that you have a maximum of session per user.
- If session conditions are too restrictive for your use case, include your account credentials as parameters for authenticated requests where `user_id` is your username and `password` is your password (do this on POST / PUT / DELETE request, not on GET)

To allow users of your app to contribute without registering individual accounts on the Open Food Facts website, you can create a global account. This way, we know that these contributions came from your application.

> The account you create in the production environment will only work for requests in production. You need to create an account in the [staging environment](https://world.openfoodfacts.net) if you want to make authenticated requests in staging.

## Reference Documentation (OpenAPI)

We are building a complete OpenAPI reference. 
See [the OpenAPI documentation](../reference/api.md)

An [older doc is also available](https://github.com/openfoodfacts/api-documentation/)


## Tutorials

See [Using OFF API tutorial](../tutorials/using-the-OFF-API-tutorial.md) which is a good introduction on how to use the API.

## Help

- Try the [FAQ](https://support.openfoodfacts.org/help/en-gb/12-api) - to answer most of your questions.
- Didn't get a satisfactory answer? Contact the Team on the #api [Slack Channel.](https://slack.openfoodfacts.org/)
- [Report Bugs](https://github.com/openfoodfacts/openfoodfacts-server/issues/new/choose) on the Open Food Facts Database.
- Do you have an issue or feature request? You can submit it [here on GitHub](https://github.com/openfoodfacts/openfoodfacts-server/issues/new).
- Are you interested in contributing to this project? See our [Contribution Guidelines](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/CONTRIBUTING.md).
 <!-- Embed contribution guideline link.-->

## SDKS

SDKs are available for specific languages to facilitate the usage of the API. We probably have a wrapper for your favorite programming language. If we do, you can use it and improve it. If we don't, you can help create it. They will let you consume data and let your users contribute new data.
Open-source contributors develop our SDKs, and more contributions are welcome to improve these SDKs. You can start by checking the existing issues in their respective repositories.

> **Warning**: Before exploring any SDK, endeavor to read the [Before You Start section](#before-you-start). Also remember, in case of problem, to check the [API Reference Documentation](https://openfoodfacts.github.io/openfoodfacts-server/reference/api.html) first to verify if the problem is in SDK implementation or in the API itself.

<!--Add published link to the Before you start and  API reference -->

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
- [Java](https://github.com/openfoodfacts/openfoodfacts-java)
- [RUST](https://github.com/openfoodfacts/openfoodfacts-rust)
- [R](https://github.com/openfoodfacts/r-dashboard)
