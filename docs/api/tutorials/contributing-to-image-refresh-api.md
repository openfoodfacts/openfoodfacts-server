#  Using the Image Refresh API

This tutorial explains how to use the Open Food Facts API to identify which product images are missing or outdated. This allows your application to prompt users to take or retake specific photos, helping keep the database current and complete. The more drastic solution is to put back the user into a refresh/completion pipeline before he can access the product.

### Core Concept

The goal is to request a special field, `images_to_update_[lang]`, for a given product. The API will return a list of key image types (front, ingredients, etc.) and a value indicating their status: either they are missing or they are old.

-----

### The API Endpoint

To get the status of a product's images, you make a standard `GET` request to the product endpoint and specify the `images_to_update_[lang]` in the `fields` parameter.

**URL Structure:**

```sh
https://{world|fr|...}.openfoodfacts.org/api/v2/product/[BARCODE]?fields=images_to_update_[LANG]
```

**Parameters:**

  - `[BARCODE]`: The barcode of the product you are querying.
  - `[LANG]`: The two-letter [ISO language code](https://static.openfoodfacts.org/data/taxonomies/languages.json) for which you want to check the images (e.g., `en`, `fr`, `de`). Your application should use its current language setting here.

**Example Request:**

Here is a request for the French (`fr`) images for product `3483130043180`.

```sh
https://fr.openfoodfacts.org/api/v2/produit/3483130043180?fields=images_to_update_fr
```

-----

### Understanding the API Response

The API returns a standard product JSON object, but it will only contain the `images_to_update_[lang]` field you requested.

**Sample Response:**

```json
{
  "product": {
    "images_to_update_fr": {
      "packaging_fr": 0,
      "front_fr": 83734290,
      "ingredients_fr": 83734290
    }
  }
}
```

**Interpreting the Response:**

The `images_to_update_fr` object contains key-value pairs.

- **Key**: The key is a combination of the **image type** and the **language code**, separated by an underscore (e.g., `front_fr`). The main image types are:
      - `front`
      - `ingredients`
      - `nutrition`
      - `packaging`
  - **Value**: The value tells you the status of the image.
      - `0`: The image **does not exist**. The user should be prompted to **take** a new picture.
      - `> 0`: The image **exists but is old**. The value is the age of the image in **seconds**. The user should be prompted to **refresh** it with a new one.

-----

### Client-Side Implementation Logic

Your application should parse this response to dynamically generate calls to action (like buttons).

#### Generating Button Text

Here is a pseudo-code example demonstrating how to create button text based on the API response.

``` js
// Assume 'images_to_update' is the object from the API response
// e.g., { packaging_fr: 0, front_fr: 83734290 }

for (key, value) in images_to_update:
    // 1. Determine the action (verb)
    let verb = ""
    if value == 0:
        verb = "Take"  // Image is missing
    else:
        verb = "Refresh" // Image is old

    // 2. Get the field name and language
    // e.g., "front_fr" -> ["front", "fr"]
    let parts = key.split("_")
    let field_name = parts[0]
    let field_language = parts[1] // Useful for localization

    // 3. Create the button text
    // You would use localized strings in a real app
    let button_text = `${verb} ${field_name} picture`

    // Now, create a button with this text.
    // e.g., "Refresh front picture", "Take packaging picture"
```

#### Optional: Displaying the Image Age

For images that need refreshing (where the value is `> 0`), you can provide more context to the user by converting the age in seconds to a human-readable format.

**Example Conversion Logic:**

You can use a library or a simple function to convert seconds into years, months, days, etc.

```javascript
function formatTime(seconds) {
  if (seconds < 60) return "just now";

  const units = {
    year: 31536000,
    month: 2592000,
    week: 604800,
    day: 86400,
    hour: 3600,
    minute: 60
  };

  for (let unit in units) {
    const value = units[unit];
    if (seconds >= value) {
      const count = Math.floor(seconds / value);
      return `${count} ${unit}${count > 1 ? 's' : ''} ago`;
    }
  }
}

// Using the value from the sample response
let age_in_seconds = 83734290;
console.log(formatTime(age_in_seconds)); // Output: "2 years ago"
```

You can then display this next to your button: "Refresh front picture (photo from 2 years ago)".
