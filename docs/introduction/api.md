# Open Food Facts API Documentation

Everything you need to know about Open FOod Facts API.

## Overview

Open Food Facts is a food products database made by everyone, for everyone that can help you make better food choices. Seeing it is open data, anyone can reuse it for any purpose. For example, building a nutrition app.
The Open Food Facts API enables developers to add to the products database and also retrieve information about existing products. You may use the API to build applications that will allow users contribute to the database and also make healthier food choices.
The current version of the API is `2`.

<!--- We can add a disclaimer image beside the next paragraph, instead of making it a subheading -->

Data in the Open Food Facts database is provided voluntarily by users who want to support the program. As a result, there are no assurances that the data is accurate, complete, or reliable. The user assumes the entire risk of using the data.

## Environment

The OpenFoodFacts API has two environments.

- Production: <https://world.openfoodfacts.org>
- Staging: <https://world.openfoodfacts.net>

Consider using the [staging enviroment]( https://world.openfoodfacts.net) if you are not in a production scenario. While testing your applications, make all API requests to the staging environment. This way, we can ensure the product database is safe.

The staging environment has an extra level of authentication (username: off, password: off). When making API requests to staging, you may use <https://off:off@world.openfoodfacts.net/> as the base URL to include the authentication.

## Authentication

All requests do not require authentication except for Editing an Existing Product.
<!---We may want to explain why -->
Create an account on the [Open Food Facts app](https://world.openfoodfacts.org/). Your should include your account credentials as parameters for authenticated requests where `user_id` is your username and `password` is your password.

To allow users of your app to contribute without having to register individual accounts on the Open Food Facts website, you can create a global account. This way, we know that these contributions came from your application.

> The account you create in the production environment will only work for requests in production. You need to create an account in the staging environment if you want to make authenticated requests in staging.

## SDKS

<!--Add a reason why we created SDKs in OFF and what it can be used for -->

[Cordova](https://github.com/openfoodfacts/openfoodfacts-cordova-app)
[DART](https://github.com/openfoodfacts/openfoodfacts-dart/blob/master/DOCUMENTATION.md)
[Elixir](https://github.com/openfoodfacts/openfoodfacts-elixir)
[Go](https://github.com/openfoodfacts/openfoodfacts-go)
[NodeJS](https://github.com/openfoodfacts/openfoodfacts-nodejs)
[PHP](https://github.com/openfoodfacts/openfoodfacts-php)
[Laravel](https://github.com/openfoodfacts/openfoodfacts-laravel)
[Python](https://github.com/openfoodfacts/openfoodfacts-python)
[React Native](https://github.com/openfoodfacts/openfoodfacts-react-native)
[Ruby](https://github.com/openfoodfacts/openfoodfacts-ruby)

## Tutorials
<!--Have different categories of Tutorials and include the links in this session -->

## Help

- Try the FAQ - to answer most of your questions.
- Didnt get a satisfactory answer? Contact the Team on the Slack Channel.
<!---Are we sure the next level of support is from FAQ to slack, If yes embed links -->
- Report Bugs on the Open Food Facts Database.
- Have an issue or feature request? You can submit it here [here on GitHub](https://github.com/openfoodfacts/openfoodfacts-server/issues/new).
- Are you interested in contributing to this project? See your Contribution Guidelines.<!-- Embed contribution guideline link>