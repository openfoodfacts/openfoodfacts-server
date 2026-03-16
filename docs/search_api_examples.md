# Open Food Facts Search API Examples
<!-- This document provides examples for using the Open Food Facts Search API.

The endpoint is:

https://world.openfoodfacts.org/cgi/search.pl -->

## Basic Search
Search for products using a keyword.

Example:

https://world.openfoodfacts.org/cgi/search.pl?search_terms=milk&json=1

## Pagination
You can paginate results using `page` and `page_size`.

Example:

https://world.openfoodfacts.org/cgi/search.pl?search_terms=milk&page=2&page_size=20&jason=1

## Filter by Country
Example:

https://world.openfoodfacts.org/cgi/search.pl?search_terms=milk&countries_tags=en:india&json=1

## Combining Filters
Example:

https://world.openfoodfacts.org/cgi/search.pl?search_terms=milk&countries_tags=en:india&nutrition_grade_tags=a&json=1




