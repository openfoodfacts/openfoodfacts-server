## Taxonomies Folder: Core Data Structure of Open Food Facts

The `taxonomies` folder within the `openfoodfacts-server` repository is central to how Open Food Facts structures its vast product data. These taxonomies define and organize crucial information such as ingredients, labels, additives, and more, allowing for consistent data processing and enhanced analysis (e.g., Nutri-Score calculation, allergen detection).
Learn more at https://wiki.openfoodfacts.org/Global_taxonomies
---

### Structure and Purpose

Each taxonomy is stored as a **raw text file**, representing a Directed Acyclic Graph (DAG). In this structure, each leaf node typically has one or more parent nodes, creating a hierarchical classification. While these files are fundamental to the database, their raw text format can be lengthy and challenging for direct editing by contributors.

For more user-friendly management and contribution, the **[Open Food Facts Taxonomy Editor](https://github.com/openfoodfacts/taxonomy-editor)** project provides a web-based interface. This editor simplifies tasks like:

* **Searching and navigating** through taxonomies.
* Enabling **translations and synonyms** to enrich the data.
* **Spotting and resolving issues** within the taxonomy structure.

---

### Adding New Logos for Labels

When contributing new logos for labels, follow these guidelines to ensure consistency and proper integration:

* **Logo Quality**: Obtain high-quality logos, preferably from official websites and in vector format if possible. Avoid using contributor photos, as they are often unsuitable for this purpose.
* **File Naming Convention**:
    * Name the file as `name-of-the-label.[width]x90.png`. The `[width]` refers to the logo's width when its height is scaled to 90 pixels.
    * Filenames must be **unaccented**, **lowercase**, and use hyphens (`-`) instead of spaces.
    * **Example**: “Kvalitatīvs produkts ražots Latvijā” → `kvalitativs-produkts-razots-latvija.123x90.png`
* **Directory Placement**: Place the logo file in the language-specific directory that corresponds to its canonical name. The root directory for label logos is:
    * **[html/images/lang/ in openfoodfacts-server](https://github.com/openfoodfacts/openfoodfacts-server/tree/main/html/images/lang)**

For detailed instructions on adding new logos, refer to the **[Open Food Facts Support page on adding new logos for labels](https://support.openfoodfacts.org/help/en-gb/15-improving-open-food-facts-in-my-language-country/55-i-would-like-to-add-a-new-logo-for-labels)**.

---

### Knowledge Panels in Open Food Facts Web

The `knowledge_panels` folder, found in repositories like **[openfoodfacts-web](https://github.com/openfoodfacts/openfoodfacts-web/tree/main/knowledge_panels)**, plays a crucial role in how information is presented to users on the Open Food Facts website and mobile applications. It lets you create a knowledge panel for each entry in each taxonomy. You can learn more at https://wiki.openfoodfacts.org/Knowledge_Team (especially the presentation made during CommuniTea)

* **Purpose**: Knowledge Panels are designed to deliver rich, contextual information, insights, and recommendations to users. They transform raw product data (e.g., nutrition facts, ingredients) into easily understandable, ready-to-display formats like tables, charts, or explanatory texts.
* 
Knowledge Panels are a key component in enhancing user experience by providing comprehensive and digestible information about food products.

--- 
### Adding official warnings
* See /docs/dev/how-to-add-generic-recommendation-panel.md on how to add official warnings
