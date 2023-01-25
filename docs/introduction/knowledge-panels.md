# Knowledge panels

The Open Food Facts API allows clients (such as the Open Food Facts website and mobile app) to request ready to display bits of information about an object (such as a product or a facet like a category).

Clients do not have to know in advance what kind of information is displayed (e.g. the ingredients of a product, nutrition data, the Nutri-Score or the Eco-Score), they only have to know how to display basic types of data such as texts, grades, images, and tables.

The structure of the knowledge panels data returned by the API is described in the panels JSON schema.

See the reference documentation: 
https://openfoodfacts.github.io/openfoodfacts-server/reference/api/#tag/Read-Requests/operation/get-product-by-barcode-knowledge-panels

See also the [source file, containing json schema](../reference/schemas/knowledge_panels/panels.yaml)