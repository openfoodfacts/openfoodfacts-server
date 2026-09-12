# Ensuring User Scans Are Counted and Enhancing Availability Data with Open Prices

This guide will help you ensure that your users' scans are properly counted, explain why it matters, and show how to go even further with the Open Prices project.

---

## Why should you make sure scans are counted?

Properly reporting scans from your app provides several key benefits:

- **Popularity Statistics:** Accurate scan counts help OFF understand which products are frequently scanned, indicating popularity and consumer interest.
- **Allowing us to gauge our aggregated impact:** This allows to create aggregated scan counts with real impact on 1st and 3rd party users, measuring our social impact.
- **Product Availability:** Frequent scans in a region suggest a product is available there, helping keep the database up to date.
- **Data Quality:** More scans can signal which products need updating, corrections, or more data.
- **Country of Sale:** Scan metadata can be used to deduce in which countries products are actually sold, especially when paired with price data.

---

## How to Ensure Scans from Your App Are Counted

To count a scan, your app must send a request to the OFF API with a special HTTP header. This header **must contain the word "Scan"** (case-insensitive). This lets Open Food Facts distinguish user-initiated scans from other API calls (like lookups or background syncs).

### Example: Including the Scan Header

When making a request (e.g., fetching a product by barcode), add a custom header such as:


```http
GET /api/v2/product/1234567890123.json HTTP/1.1
Host: world.openfoodfacts.org
User-Agent: MyAwesomeScanner - 1.0 (Build 21E236) ios - scan
X-OpenFoodFacts-Scan: Scan; app=MyAwesomeScanner; version=1.0
```

**Requirements:**
- The header value **must include the word "Scan" at the end** of the user agent, even if the app name already contains the word scan.

**Tip:** You can add more info such as app name, version, platform, etc. since they are useful for debugging issues we may encounter

---

## Adding even more info on availability: The Benefits of Open Prices

[Open Prices](https://prices.openfoodfacts.org/docs) is a companion project that collects product price data. By submitting price information along with scans, you help:

- **Deduce Product Availability:** If a product has a price at a location, it's likely available at that location at the given date of the price.
- **Track Price Trends:** Useful for economic research and consumer transparency.
- **Improve Country of Sale Data:** Price submissions often come with store and country info, helping refine product distribution data.

---

## How to Let Users Add Price Points

You can enable users to submit price data in your app. Here’s how:

1. **Prompt users** to add the price after scanning a product.
2. **Send a POST request** to the Open Prices API endpoint with the relevant data.

[Get started with Open Prices](/docs/api/tutorials/product-prices.md)


Thank you for helping make food data more open, accurate, and useful!
