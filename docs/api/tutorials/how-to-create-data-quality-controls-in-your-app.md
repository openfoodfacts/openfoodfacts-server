Ensuring Data Quality for Open Food Facts Contributions
-------------------------------------------------------

This tutorial will guide you through best practices for maintaining high-quality data contributions to Open Food Facts through your app. As you know, Open Food Facts (and your app, since you have implemented or are implementing contributing back to Open Food Facts) leverages crowdsourcing, which is a fantastic way to gather a vast amount of information. However, it also necessitates measures to ensure data accuracy.

### Prevention is Key

The most effective approach lies in prevention. Here's how your app's interface can play a crucial role:

-   **Instant Feedback:**

    -   Nutritional values: Implement checks that flag inconsistencies and prompt users to verify their entries.
    -   Ingredient language compatibility: Ensure users take legible photos of the ingredient list, and send them in the actual language they are written in.
    -   Selfie detection: On-device libraries [like MLKit](https://developers.google.com/ml-kit/vision/face-detection/android) can detect whether the user is taking a selfie instead of a product, and can warn them about it. 
-   **Data Quality Facets:** Utilize the data quality facets established by Open Food Facts and recode some (or all of) them within your app. These facets act as guidelines for your users to ensure comprehensive and accurate data collection.

-   **Non-Food Item Prevention:** Implement functionalities that routes non-food items like cosmetics to the right database (just ask your users if it's a food or a cosmetic).

### Addressing Errors and Malicious Intent

-   **Acknowledging that Errors may happen:** It's inevitable that some users might unintentionally or deliberately submit inaccurate data. Be prepared for such situations.

-   **Versioning and User Anonymization:**\
    When sending data to Open Food Facts, include the app version used for the contribution along with an anonymized user identifier. This allows Open Food Facts to block repeat offenders (and not your app's global account) individually if necessary, without the need for them to create an Open Food Facts account.

-   **Collaboration:**\
    If you suspect recurring issues with user-generated data potentially stemming from app functionalities, don't hesitate to reach out to the Open Food Facts team. We're happy to assist in troubleshooting, UI feedback…

### Cater for the complexity in Food & Nutrition Data

-   **Edge Cases:**\
    Food and nutrition data can be intricate. Consider edge cases like dehydrated products that require rehydration for accurate nutritional value representation.

-   **Global Variations:**\
    Nutritional facts tables differ internationally. Be mindful of these variations (e.g., US vs. European formats) and the need for appropriate labeling within your app.

-   **"As Sold" vs. "As Prepared" Values:**\
    Nutritional information can be presented based on the product's state, "as sold" or "as prepared." Ensure clarity within your app regarding these variations.

- **A photo is better than nothing at all or bad data alone**
  Using a photo helps us cross-check the edits by your users, use artificial intelligence to compare the product to similar products in the same category. It also helps us complete the product at a later time if your users doesn't have the courage to input the data, or if he inputs bad data. A photo of the nutrition table and of the ingredients will go *a very long way*

By following these guidelines and fostering a collaborative approach with Open Food Facts, your app can significantly contribute to a high-quality data collection effort, empowering informed consumer choices.
