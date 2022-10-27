### Translations
You can translate Open Food Facts at https://translate.openfoodfacts.org. Please do not translate directly in the code, or your translations will be overwritten.

If you want to add a translatable string in the code:
* modify the file with the `.pot` extension depending on your context. Eg.
  ```pot
  msgctxt "name_of_your_string"
  msgid "Hello world!"
  msgstr ""
  ```
* use your new string with the `lang()` function. Eg. in a template file: `[% lang('name_of_your_string') %]`
* if you want to test your modifications in your dev environnement:
  * modify the `en.po` and the `fr.po` files if you want to test in English and French; be aware it's just for test: these files will be overwritten by Crowdin. Eg. in French:
    ```pot
    msgctxt "name_of_your_string"
    msgid "Hello world!"
    msgstr "Salut le monde!"
    ```
  * don't forget to `make build_lang` to let docker take your modifications into account
