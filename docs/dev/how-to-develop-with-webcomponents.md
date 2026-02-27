# How to use WebComponents
- We have a variety of Web Components to do the hard work for you: explore them at [openfoodfacts-webcomponents](https://github.com/openfoodfacts/openfoodfacts-webcomponents)
- Nutrition extraction, Ingredient extraction, Robotoff questions, spellcheck, barcode scanner for PWA, Product card, and more.

# How to develop with WebComponents

If you are developing a new WebComponent in [openfoodfacts-webcomponents](https://github.com/openfoodfacts/openfoodfacts-webcomponents) project,
you might want to test its integration immediately.

To do this you can use the following steps:

1. Define the `WEBCOMPONENTS_DIR` in your .env file (or better .envrc if you use that)
   to point to  the relative location corresponding to your webcomponents project.
   For example: `../openfoodfacts-webcomponents`.


2. Modify the `package.json` file so that the webcomponents dependency
   is not a version anymore but instead `/opt/webcomponents`:

   ```diff
   -    "@openfoodfacts/openfoodfacts-webcomponents": "1.12.3"
   +    "@openfoodfacts/openfoodfacts-webcomponents": "/opt/webcomponents",
   ```

3. Don't forget to build your webcomponents (got to webcomponents directory and run `npm build`)

4. Restart the dynamicfront container (`docker-compose restart dynamicfront`)


> **BEWARE**: not to commit your `.env`, `package.json`  and `package-lock.json` changes !
