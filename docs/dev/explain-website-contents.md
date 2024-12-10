# Explain Website Contents

The Open Food Facts site has content pages that explain the project and its goals,
or give explanations on important topics.

Those contents comes from two sources:

* the openfoodfacts-web repository
* an external CMS, which is an instance WordPress

## CMS Pages

The pages from the CMS are the new way of creating content.
They offer an easy to use interface to create and edit content, for non technical users.

Note: We don't use pages but posts, because they have tags
which can be used to filter the pages according to the Product Opener instance.

We use the WPML plugin to enable internationalization and translation of pages.
WPML is connected to crowdin so that we can have our community translate the contents.

We talk to the WordPress API to get the content of the pages.
At startup, `load_data`, calls `load_cms_data`
which will use the API to get the known pages with some metadata.

A special URL, available to administrators, `/content/refresh`
can be used to call `load_cms_data` again, and refresh the pages list.


### Crowdin / WPML integration

See [How to setup wordpress](./how-to-setup-wordpress.md)

### How to create a page

See https://wiki.openfoodfacts.org/Open_Food_Facts_Contents

## openfoodfacts-web Pages

This is the historic way of creating contents, and is still used for some pages.
As contents are reworked, we should try to use the CMS pages.

The contents are html files in the `openfoodfacts-web` repository, under the `lang/xx/texts` folders.

This repository also contains translations for emails, or additives and will remain valid for those specific contents.

Because it uses plain html files, it is complicated for non technical users to edit the contents.

The integration with crowdin is done through the usual github / crowdin workflow.

### Connecting pages to the website

See [How to use pages from openfoodfacts-web](./how-to-use-pages-from-openfoodfacts-web.md)


## How to migrate from openfoodfacts-web to the CMS

See https://wiki.openfoodfacts.org/Open_Food_Facts_Contents#How_to:_replace_an_Openfoodfacts-web_page_by_a_Wordpress_page_.28Not_yet_in_production.29
