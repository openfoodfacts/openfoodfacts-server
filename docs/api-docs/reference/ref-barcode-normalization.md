# Reference: Barcode Normalization

This reference describes how barcodes are normalized in Open Food Facts.

## The problem: barcodes may be prefixed by a varying number of 0s

Different types of barcodes can be found on products. The most common are:

* EAN-13 / GTIN-13: 13 digit barcode
* EAN-8: 8 digit barcode, short version of EAN-13 barcodes that have 5 leading 0s
* UPC-A / UPC-12: 12 digit barcode that were used mostly in the US and Canada. A leading 0 can be added to get the corresponding EAN-13.
* UPC-E: 7 digit barcode, short version of UPC-A
* EAN-14 / GTIN-14: used for non-consumer facing products (e.g. a case of individal products). a leading 0 can be added to EAN-13 to get the corresponding EAN-14.

The same code could be printed on products with a different number of leading 0s.
Additionally, some barcode scanners may add or remove leading 0s.

As the barcode is used as the key in Open Food Facts, we can end up with duplicate products that just differ by the number of leading 0s.

## The solution: barcode normalization

In Open Food Facts, we choose to fix the number of leading 0s in this way:

All barcodes with 7 digits or less (after leading 0s are removed) are padded with leading 0s so that they have 8 digits.

All barcodes with 9 to 12 digits are padded with leading 0s so that they have 13 digits.

The "code" field in the product database, database dumps and exports is normalized in this way.

### Normalization of barcodes in the API

The Open Food Facts API automatically normalize the barcode passed in the "code" field for both READ and WRITE requests.

So a request for the 12 digit barcode 034000470693 will return the product saved with "code" 0034000470693.