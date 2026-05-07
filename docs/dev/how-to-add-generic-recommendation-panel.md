# How to Add a Generic Recommendation Panel for a Category

This tutorial explains how to add a new recommendation or warning panel that appears on product pages belonging to a specific category. This panel is displayed based on properties set in the category taxonomy. An example of the final result is shown below:

These panels are intended for **official, science-based warnings** from recognized public health or government organizations.

-----

## Eligibility for a Recommendation Panel

Before adding a panel, ensure the information meets the following criteria:

  * The warning or recommendation must come from an **official source** (e.g., a national health agency, the World Health Organization).
  * The information must be **science-based** and widely accepted by the scientific community.
  * A direct link to the source must be provided for verification.

-----

## Steps to Implement a New Panel

The process involves two main steps: updating the relevant category taxonomy and adding the corresponding text strings for display.

### Step 1: Add Properties to the Category Taxonomy

You need to edit the taxonomy file for the relevant category (e.g., `categories.txt`) and add a set of properties to the specific category entry.

The following properties control the panel's appearance and content:

| Property                                      | Description                                                                                          | Example Value                                                                                             |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `recommendation_panel_id:en`                  | A general identifier for the type of recommendation.                                                 | `recommendation_health`                                                                                   |
| `recommendation_panel_evaluation:en`          | The evaluation context, which affects the panel's color and icon (e.g., 'bad', 'warning', 'good').     | `bad`                                                                                                     |
| `recommendation_panel_icon:en`                | The icon to be displayed in the panel header. The icon must exist in the project assets.             | `arrow-bottom-right-thick.svg`                                                                            |
| `recommendation_panel_msgctxt_prefix:en`      | A unique prefix used to look up the title, subtitle, and text from the translation files.            | `recommendation_eu_tobacco_health_warning`                                                                |
| `recommendation_panel_source_url:en`          | The full URL to the official source of the information.                                              | `https://health.ec.europa.eu/tobacco/product-regulation/health-warnings_en` |
| `recommendation_panel_source_language:en`     | The language code of the source URL.                                                                 | `en`                                                                                                      |

#### Example: EU Tobacco Health Warning

To add the European Union's official health warning to a "Tobacco" category, you would add the following lines to its entry in the taxonomy file:

```properties
	recommendation_panel_id:en: recommendation_health
	recommendation_panel_evaluation:en: bad
	recommendation_panel_icon:en: arrow-bottom-right-thick.svg
	recommendation_panel_msgctxt_prefix:en: recommendation_eu_tobacco_health_warning
	recommendation_panel_source_url:en: https://health.ec.europa.eu/tobacco/product-regulation/health-warnings_en
	recommendation_panel_source_language:en: en
```

### Step 2: Add the Display Strings

The value you set for `recommendation_panel_msgctxt_prefix` is used to create keys for the text that will be displayed. The system will look for three specific keys derived from this prefix:

  * `prefix_title`
  * `prefix_subtitle`
  * `prefix_text`

You must add these entries to the localization files (`.po` files) so they can be displayed and translated.

#### Example: Strings for the Tobacco Warning

Using the prefix `recommendation_eu_tobacco_health_warning` from the previous step, you would add the following to the relevant `.po` file:

```po
	msgctxt "recommendation_eu_tobacco_health_warning_title"
	msgid "Smoking kills"
	msgstr "Smoking kills"

	msgctxt "recommendation_eu_tobacco_health_warning_subtitle"
	msgid "Tobacco seriously damages health. Don't start or quit now."
	msgstr "Tobacco seriously damages health. Don't start or quit now."

	msgctxt "recommendation_eu_tobacco_health_warning_text"
	msgid "Smoking is highly addictive. Don't start. Smoking kills – quit now. Smoking clogs the arteries and causes heart attacks and strokes. Smoking causes fatal lung cancer. Smoking when pregnant harms your baby. Protect children: don't make them breathe your smoke. Your doctor or your pharmacist can help you stop smoking. Smoking may reduce the blood flow and causes impotence. Smoking causes ageing of the skin. Smoking can damage the sperm and decreases fertility. Smoke contains benzene, nitrosamines, formaldehyde and hydrogen cyanide."
	msgstr "Smoking is highly addictive. Don't start. Smoking kills – quit now. Smoking clogs the arteries and causes heart attacks and strokes. Smoking causes fatal lung cancer. Smoking when pregnant harms your baby. Protect children: don't make them breathe your smoke. Your doctor or your pharmacist can help you stop smoking. Smoking may reduce the blood flow and causes impotence. Smoking causes ageing of the skin. Smoking can damage the sperm and decreases fertility. Smoke contains benzene, nitrosamines, formaldehyde and hydrogen cyanide."
```

-----

## (Optional) Creating Country-Specific Recommendations

To display a specific recommendation for a single country, you can add a country code suffix to the relevant properties. The system will prioritize the country-specific properties over the default ones when viewed by a user from that country.

#### Example: French-Specific Tobacco Warning

To add a different source and set of strings for users in France (country code: `fr`), you would add the following properties **in addition** to the default ones:

```properties
	recommendation_panel_msgctxt_prefix_fr:en: recommendation_eu_tobacco_health_warning_fr
	recommendation_panel_source_url_fr:en: https://www.tabac-info-service.fr/
	recommendation_panel_source_language_fr:en: fr
```

You would then need to add the corresponding strings to the `.po` files using the new prefix:

```po
	msgctxt "recommendation_eu_tobacco_health_warning_fr_title"
	msgid "Fumer tue"
	msgstr "Fumer tue"

	msgctxt "recommendation_eu_tobacco_health_warning_fr_subtitle"
	msgid "Le tabac nuit gravement à votre santé. Ne commencez pas, ou arrêtez maintenant."
	msgstr "Le tabac nuit gravement à votre santé. Ne commencez pas, ou arrêtez maintenant."

    ...etc
```

-----

## Final Check

Once you have made these changes:

1.  Test your implementation locally to ensure the panel appears correctly on the product pages of the targeted category.
2.  Submit a pull request with your changes to the taxonomy and localization files.
3.  Clearly explain the official source of the warning in your pull request description.
