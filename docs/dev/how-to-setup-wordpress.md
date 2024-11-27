# How to setup wordpress for contents

We use a WordPress instance to manage the contents of the site.
See [Explain Website contents](./explain-website-contents.md)

## Install WPGraphQL extension

Install https://wordpress.org/plugins/wp-graphql/
for Product Opener will use the GraphQL API to get the contents.

## Install WPML extension

This is a plugin to manage translations of contents.
It is not free, but has the advantage to be integrated with crowdin,
and to have more advanced features than PolyLang.

Install WPML media translations and WPML Multilingual CMS extensions.

We also install the WPML GraphQL extension.

## WPML configuration

In *WPML* menu, *settings submenu*, *Taxonomies Translations*, tell that Tags and Categories are not translatable.

## Connect WPML to crowdin

In crowdin, I used the *openfoodfacts* account (linked to *tech* email address).

Connect to crowdin, go to the store, and install the [WPML app](https://store.crowdin.com/wpml-app).

I installed it to the *openfoodfacts* project.

Go to *openfoodfacts* project, in *integrations* tab, click on *create token*, and copy the token value.

In the configuration of WPML, go to the *Translation management* menu, *Translators* tab and activate Crowdin.
In the Crowdin box, click on *authenticate* button and paste the token value, then submit.


## Setting up languages

We must have the same list of languages in our project as in Crowdin.

To get the list of crowdin languages, go to the crowdin project, then to *Settings* tab, and [*languages* entry](https://crowdin.com/project/openfoodfacts/settings#languages). (using `$x("//*[@id='target_languages_result']//text()").map(x => x.textContent).join("\n")` in a console may help getting the list as text)

Also those must match the [languages codes from crowdin](https://support.crowdin.com/developer/language-codes/)

In Wordpress, go to the *WPML, Languages* sub menu, and add languages.


We have some differences between default WPML langage codes, that we have to setup by ourselves.
For that, from the page to add languages , we got to the "edit languages" page,
there we change some codes ( column): 
* es -> es-ES
,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant


## Test sending translations

Go to *WPML* menu, *Translation Management* sub menu, *Dashboard* tab.
Select an article, and all languages.

Then chose on the *Assign to translator*, and click *Add to translation Basket*.

Then go to the *Translation Basket* tab, set a batch name and timeline,
verify all contents are set to *Crowdin* as translator, and click on "Send all items for translation".

If you got problems, you may look at the *communication log* (link at the bottom of the page).

11/27/2024 10:59:59 am - error - (27) Crowdin doesn't support the following language pair: en -> es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant.<br />Please <a href='https://crowdin.com/'>contact Crowdin</a> and ask them to add mapping for en to es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant, so they can receive this job. You can send them this email:<br /><i>Dear Crowdin,<br />I wanted to let you know that you're currently not supporting en to es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant which I am hoping to use on my website.<br />Could you update the configuration to ensure it works for me in the future?<br />Regards</i>