### Translations
You can translate Open Food Facts at https://translate.openfoodfacts.org thanks to the Crowdin platform. Please do not translate directly in the code, or your translations will be overwritten.

If you want to add a translatable string in the code:
* modify the file with the `.pot` extension related to your context. Eg.
  ```pot
  msgctxt "name_of_your_string"
  msgid "Hello world!"
  msgstr ""
  ```
* modify the file `en.po` related to your context, to be sure at least an english string will be displayed before Crowdin send back all `.po` files (which can take several days). It should be the same code as the one from `.pot` + the english transaltion (see `msgstr` field). Eg.
  ```po
  msgctxt "name_of_your_string"
  msgid "Hello world!"
  msgstr "Hello world!"
  ```
* use your new string with the `lang()` function. Eg. in a template file: `[% lang('name_of_your_string') %]`
* if you want to test your modifications in your dev environnement:
  * modify the `fr.po` files if you want to test in French; be aware it's just for test: these files will be overwritten by Crowdin. Eg. in French:
    ```pot
    msgctxt "name_of_your_string"
    msgid "Hello world!"
    msgstr "Salut le monde!"
    ```
  * don't forget to `make build_lang` to let docker take your modifications into account
