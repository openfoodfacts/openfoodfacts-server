# How to use pages from openfoodfacts-web

To avoid messing the product-opener repository with translations of web pages,
we moved most pages in 
[openfoodfacts-web repository](https://github.com/openfoodfacts/openfoodfacts-web)
specifically in the lang/ directory.

This repo only has a really minimal lang directory named lang-default.

If you want to have all contents locally, 
you should first clone openfoodfacts-web repo locally, 
and then:

- if you are using docker, 
  you can set the `WEB_RESOURCES_PATH` env variable to a relative or absolute path
  leading to openfoodfacts-web directory.
- else, make symlink `lang` point to openfoodfacts-web `lang` directory, and `html/off_web_html` point to openfoodfacts-web `html` directory.
