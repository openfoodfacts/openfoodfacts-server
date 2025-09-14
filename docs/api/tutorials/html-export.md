---
title: HTML Export in Open Food Facts
description: Guide to using the Open Food Facts HTML export feature for displaying product information in webpages and embedding data in other applications
---

<!-- # HTML Export Tutorial -->

Open Food Facts provides an HTML export feature that allows you to display product information on webpages and embed data in other applications. This tutorial will guide you through the process of using this feature effectively.

## Getting Started

To use the HTML export feature, you need to have access to the Open Food Facts database. You can sign up for an account and request access to the API if you haven't already.

## Exporting HTML

The HTML export feature enables you to retrieve product information in a format that can be directly embedded into your website or application. Here's how you can use it:

1. Make an API request to the Open Food Facts database.
2. Specify the product(s) you want to export.
3. Choose the HTML format as the output.

## Example

Below is an example of an API request for HTML export:

```html
GET https://world.openfoodfacts.org/api/v0/product/[barcode].html
```

Replace `[barcode]` with the actual barcode of the product you want to retrieve.

## Embedding HTML

Once you have the HTML data, you can embed it into your webpage or application. For example:

```html
<div>
  <!-- Insert the HTML data here -->
</div>
```

## Conclusion

The HTML export feature is a powerful tool for integrating Open Food Facts data into your projects. By following this tutorial, you can easily display product information and enhance your applications with valuable data.