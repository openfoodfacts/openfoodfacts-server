**Dave** wants his app to make an API call to provide Anna the information she needs to make a conscious choice when buying sodas.

---

#### Authentication and Header

To make the API query that returns the products that might be interesting for Anna, Dave doesn't need to authenticate (`READ` request).

However, he has to add a `User-Agent` HTTP Header with the name of his app, the version, system and a url (if any), so that he doesn't get blocked by mistake.

In this case, that would be: `User-Agent: HealthyFoodChoices - Android - Version 1.0`

---

#### Subdomain

Since Anna lives in NY, Dave wants to define the subdomain for the query as `us`. The subdomain automatically defines the country code (`cc`) and language of the interface (`lc`).

The country code determines that only the products sold in the US are displayed. The language of the interface for the country code `us` is English.

In this case:

[https://us.openfoodfacts.org](https://us.openfoodfacts.org)

---

#### API Version

The current version number of the Open Food Facts API is v0.

[https://us.openfoodfacts.org/api/v0](https://us.openfoodfacts.org/api/v0)

---

#### Product Barcode

After the version number, the word "product", followed by its barcode must be added:

[https://us.openfoodfacts.org/api/v0/product/](https://us.openfoodfacts.org/api/v0/product/)

The app will provide Anna with information about additives, sugars and nutriscore of different types of colas, to help her make her purchase decision.

Anna selects the products she wants to compare in the application (Coca-Cola, Pepsi, Coca-Cola diet, Coca-Cola zero and Pepsi diet). The app retrieves the corresponding barcodes and makes the following calls:

- Pepsico Pepsi Cola Soda:  
    [https://us.openfoodfacts.org/api/v0/product/01223004](https://us.openfoodfacts.org/api/v0/product/01223004)
- Coca-Cola Classic Coke Soft Drink  
    [https://us.openfoodfacts.org/api/v0/product/04963406](https://us.openfoodfacts.org/api/v0/product/04963406)
- Diet Pepsi  
    [https://us.openfoodfacts.org/api/v0/product/069000019832](https://us.openfoodfacts.org/api/v0/product/069000019832)
- Coca-Cola Zero  
    [https://us.openfoodfacts.org/api/v0/product/5000112519945](https://us.openfoodfacts.org/api/v0/product/5000112519945)
    

---
