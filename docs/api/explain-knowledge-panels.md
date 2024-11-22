# Explanation on Knowledge panels

The Open Food Facts API allows clients (such as the Open Food Facts website and mobile app) to request ready-to-display information about an object (such as a product or a facet like a category).

Clients do not have to know in advance what kind of information is displayed (for example - the ingredients of a product, nutrition data, Nutri-Score or Eco-Score). They only have to know how to display essential data types such as texts, grades, images, and tables.

![Panels for oatmeal on the mobile app, showing ingredients and nutrition info](../assets/knowledge-panels-in-action.png)  
Knowledge panels in action on the website


Knowledge panels in action on the mobile app

## Main elements
Main elements are panels, which in turn contain elements. Elements are typically `text_element`, `image_element`, `map_element`. Some panels are grouping panels together, forming a hierarchy.
We also have a concept of action, which allows the user to take an action, currently editing.

The structure of the knowledge panels data returned by the API is described in the [knowledge panels JSON schema](./ref/schemas/knowledge_panels/panels.yaml).

> See the reference documentation for [Getting Knowledge panels for a specific product by barcode](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/product/-barcode--fields-knowledge_panels).

## How to make a knowledge panel related contribution
- You need to have a clear vision of the information you want to convey, both in synthetic and larger form
- If the information is missing to properly display the panel, you need to devise a clear way for the user to contribute it if it's available on pack, or explain that it's not available on pack

## Code-pointers
* The code contains templates and logic for creating various knowledge panels, including environmental and contribution-related panels, as seen in `templates/api/knowledge-panels/environment/label.tt.json` and `lib/ProductOpener/KnowledgePanelsContribution.pm`.
* Knowledge panels are generated based on product data and taxonomies, with support for localization and customization as per `lib/ProductOpener/KnowledgePanels.pm` (for products) and `lib/ProductOpener/KnowledgePanelsTags.pm` (for facets).

## How to test that your knowledge panel contribution does not break the app
- You can use tools such as ngrok.io to open a tunnel from your local development machine to the Internet. If you are using GitPod to run your Product Opener instance, you don't even need this step, as gitpod allows you to make your dev instance url public.
- You can then activate the DEV mode of the official Open Food Facts mobile app, switch the Server to test, and set a custom URL (yours) for the server. More details are available
