# Google Product Taxonomy to OPF Categories Converter

This directory contains scripts to generate an Open Products Facts category taxonomy based on the Google Product Taxonomy.

## Overview

The conversion process consists of 4 main steps:

1. **Fetch Google Product Taxonomy** - Downloads the hierarchical structure and translations
2. **Fetch Wikidata Mappings** - Retrieves mappings from Google Product Category IDs to Wikidata Q-IDs
3. **Extract Existing Data** - Parses the current OPF categories.txt to preserve existing data
4. **Generate Taxonomy** - Combines all data sources to create the new taxonomy file

## Prerequisites

```bash
pip install requests
```

## Usage

### Quick Start - Run All Steps

```bash
cd scripts/taxonomies/generators
python3 00_run_all.py
```

This will:
- Fetch all required data
- Generate the new taxonomy
- Save output to `google_product_taxonomy_data/new_categories.txt`

### Run Individual Steps

You can also run scripts individually:

```bash
# Step 1: Fetch Google Product Taxonomy
python3 01_fetch_google_product_taxonomy.py

# Step 2: Fetch Wikidata mappings
python3 02_fetch_wikidata_mappings.py

# Step 3: Extract existing OPF data
python3 03_extract_existing_data.py

# Step 4: Generate new taxonomy
python3 04_generate_opf_taxonomy.py
```

### Using Cached Data

If you've already fetched the data and just want to regenerate the taxonomy:

```bash
python3 00_run_all.py --skip-fetch
```

## Output Files

All output files are saved in the `google_product_taxonomy_data/` directory:

### Intermediate Data Files

- `taxonomy_structure.json` - Hierarchical structure from Google Product Taxonomy
- `translations.json` - Translations in multiple languages organized by language code
- `wikidata_mappings.json` - Mapping from Google Product Category ID to Wikidata Q-ID
- `wikidata_mappings_detailed.json` - Same as above but with labels
- `wikidata_labels.json` - Multilingual labels for Wikidata entities
- `existing_categories_data.json` - Parsed data from current OPF taxonomy
- `existing_wikidata_mappings.json` - Wikidata mappings from current taxonomy
- `existing_carbon_impact_data.json` - Carbon impact data from current taxonomy
- `existing_properties.json` - All properties from current taxonomy

### Final Output

- `new_categories.txt` - The generated taxonomy file in OPF format

## Data Sources

### Google Product Taxonomy

- **Hierarchical JSON**: https://raw.githubusercontent.com/lubianat/google_product_taxonomy_reference/refs/heads/master/data/taxonomy.json
- **Translations**: Multiple language files from https://www.google.com/basepages/producttype/

Supported languages: English, French, German, Spanish, Italian, Dutch, Portuguese, Czech, Danish, Japanese, Norwegian, Polish, Russian, Swedish, Turkish

### Wikidata

Wikidata entities with property P11302 (Google Product Category ID):
- **SPARQL Query**: https://query.wikidata.org/
- **Mappings**: Approximately 5,599 categories have Wikidata mappings

### Existing OPF Data

The scripts preserve data from the current `taxonomies/product/categories.txt`:
- Wikidata IDs
- Carbon impact data (from ImpactCO2.fr)
- Additional translations
- Custom properties

## Taxonomy Format

The generated taxonomy follows the OPF taxonomy format:

```
en: mobile phones, cell phones
de: Mobiltelefone, Handys
es: teléfonos móviles, celulares
fr: téléphones portables, téléphones mobiles

< en: mobile phones
en: Smartphones
xx: Smartphones
de: Smartphones
es: Teléfonos inteligentes
fr: Smartphones
carbon_impact_fr_impactco2:en: 85.9
carbon_impact_fr_impactco2_link:en: https://impactco2.fr/outils/numerique/smartphone
unit_name:xx: smartphone
unit_name:en: smartphone
wikidata:en: Q22645
```

### Format Rules

- `< en: parent` - Indicates parent category
- `lang: name1, name2` - Translations with synonyms
- `xx:` - International/universal terms
- `property:lang: value` - Properties like wikidata, carbon_impact, etc.

## Customization

### Adding More Languages

Edit `LANGUAGE_URLS` in `01_fetch_google_product_taxonomy.py` to add more language sources.

### Modifying Matching Logic

Edit `find_matching_existing_category()` in `04_generate_opf_taxonomy.py` to adjust how existing categories are matched with Google Product Taxonomy entries.

### Adding Properties

The scripts preserve all properties from the existing taxonomy. To add new properties, update the extraction logic in `03_extract_existing_data.py`.

## Testing

After generating the taxonomy:

1. Review the output file for correctness
2. Run taxonomy validation tests (if available)
3. Compare with the original taxonomy to ensure important data is preserved

## Troubleshooting

### Network Errors

If fetching data fails:
- Check internet connection
- Verify URLs are still valid
- Try running individual fetch scripts with delays

### Missing Data

If some categories lack translations or properties:
- Check the source data files in `google_product_taxonomy_data/`
- Verify Wikidata mappings are complete
- Review matching logic for existing categories

### Large Output File

The Google Product Taxonomy is extensive (6000+ categories). The generated file may be large. Consider:
- Filtering categories relevant to Open Products Facts
- Focusing on specific product types
- Creating separate taxonomy files by product category

## License

These scripts are part of the Open Products Facts project and follow the same license as the main repository (AGPL-3.0).

## Contributing

To improve the conversion process:
1. Test the scripts with the latest data sources
2. Improve matching algorithms
3. Add validation checks
4. Document edge cases

## Contact

For questions or issues, please open an issue on the Open Products Facts GitHub repository.
