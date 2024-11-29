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

We asked Crowdin for an account as an Open Source Project to be able to have more than one project.

This is needed because WPML does not use same id for languages as Crowdin,
and it's quite impossible to change the code on WPML side,
so we will need to map the languages in a specific way in the Crowdin project.

In crowdin, I used the *openfoodfacts* account (linked to *tech* email address).

I created the *openfoodfacts-contents* project, copying languages from the *openfoodfacts* project. And using advanced tab, I also used the same glossary and memory translation.

Then go to the store, and install the [WPML app](https://store.crowdin.com/wpml-app).

I installed it to the *openfoodfacts-contents* project.

Go to *openfoodfacts-contents* project, in *integrations* tab, click on *create token*, and copy the token value.

In the configuration of WPML, go to the *Translation management* menu, *Translators* tab and activate Crowdin.
In the Crowdin box, click on *authenticate* button and paste the token value, then submit.

Also use the "Refresh Language pairs" button.

## Setting up languages

In Wordpress, go to the *WPML, Languages* sub menu, and add languages.
I added all but Macedonian which is not supported by crowdin out of the box.


We have some differences between default WPML langage codes, that we have to setup by ourselves.
I saw that by trying to send my first batch of translations to crowdin ([see below](#test-sending-translations))

We log into Crowdin, go in the *openfoodfacts-contents* project, *settings*,
*languages* sub menu, then click on *Add custom language codes*
and change the *locale* for:
- Spanish -> es
- Irish -> ga
- Armenian -> hy
- Punjab -> pa
- Portugese -> pt-pt
- Portugese, Brazilian -> pt-br
- Swedish -> sv
- Chinese Simplified -> zh-hans
- Chinese Traditional -> zh-hant
- Nepali -> ne
- Urdu (India) -> ur

## Test sending translations

Go to *WPML* menu, *Translation Management* sub menu, *Dashboard* tab.
Select an article, and all languages.

Then chose on the *Assign to translator*, and click *Add to translation Basket*.

Then go to the *Translation Basket* tab, set a batch name and timeline,
verify all contents are set to *Crowdin* as translator, and click on "Send all items for translation".

If you got problems, you may look at the *communication log* (link at the bottom of the page).

```
11/27/2024 10:59:59 am - error - (27) Crowdin doesn't support the following language pair: en -> es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant.<br />Please <a href='https://crowdin.com/'>contact Crowdin</a> and ask them to add mapping for en to es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant, so they can receive this job. You can send them this email:<br /><i>Dear Crowdin,<br />I wanted to let you know that you're currently not supporting en to es,ga,hy,mk,ne,pa,pt-pt,pt-br,sv,ur,zh-hans,zh-hant which I am hoping to use on my website.<br />Could you update the configuration to ensure it works for me in the future?<br />Regards</i>
```

After searching a bit if I could do change the code on WPML side, which was not possible,
I fixed it by changing language mappings in Crowdin projects (and that's why it's a separate project from the main one).