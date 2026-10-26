# Google Product Taxonomy to OPF Categories Converter

This directory contains scripts to generate an Open Products Facts category taxonomy based on the Google Product Taxonomy.

## Quick Start

```bash
cd scripts/taxonomies/generators
python3 00_run_all.py
```

Output: `google_product_taxonomy_data/new_categories.txt` with 5,595 categories in 15 languages

## What This Does

The conversion process:

1. **Fetches Google Product Taxonomy** - Downloads hierarchical structure and translations in 15 languages
2. **Fetches Wikidata Mappings** - Retrieves 5,593 mappings from Google Product Category IDs to Wikidata Q-IDs  
3. **Extracts Existing Data** - Parses current OPF categories.txt to preserve existing data (wikidata, carbon impact, etc.)
4. **Generates Taxonomy** - Combines all data sources into OPF taxonomy format

## Generated Taxonomy Features

- **5,595 categories** from Google Product Taxonomy
- **15 languages**: English, French, German, Spanish, Italian, Dutch, Portuguese, Czech, Danish, Japanese, Norwegian, Polish, Russian, Swedish, Turkish
- **5,593 Wikidata mappings** (99.9% coverage via property P11302)
- **Preserved data** from existing taxonomy: carbon impact (51 categories), custom properties
- **Hierarchical structure** with parent-child relationships
- **OPF format** compatible with existing taxonomy system

## Scripts

- **00_run_all.py** - Master script to run entire pipeline
- **01_fetch_google_product_taxonomy.py** - Fetch taxonomy structure and translations
- **02_fetch_wikidata_mappings.py** - Query Wikidata for category mappings
- **03_extract_existing_data.py** - Parse existing OPF categories.txt
- **04_generate_opf_taxonomy.py** - Generate final taxonomy file

## Documentation

- **README_GPC_CONVERSION.md** - Original detailed overview
- **USAGE_GUIDE.md** - Comprehensive guide with examples and customization
- **EXAMPLE_OUTPUT.txt** - Sample of generated taxonomy
- **IMPLEMENTATION_CHECKLIST.md** - Production deployment checklist

## Prerequisites

```bash
pip install requests
```

## Usage Examples

### Generate Full Taxonomy
```bash
python3 00_run_all.py
```

### Use Cached Data (skip network fetch)
```bash
python3 00_run_all.py --skip-fetch
```

### Run Individual Steps
```bash
python3 01_fetch_google_product_taxonomy.py
python3 02_fetch_wikidata_mappings.py
python3 03_extract_existing_data.py
python3 04_generate_opf_taxonomy.py
```

### Test Installation
```bash
./test_scripts.sh
```

## Output Files

All files are saved in `google_product_taxonomy_data/`:

**Intermediate data:**
- `taxonomy_structure.json` - Hierarchical structure
- `translations.json` - Translations by language
- `wikidata_mappings.json` - GPC ID to Wikidata Q-ID
- `existing_*.json` - Data from current taxonomy

**Final output:**
- `new_categories.txt` - Generated taxonomy (3MB, 112k lines)

## Example Output

```text
en: Animals & Pet Supplies
cs: Chovatelství
de: Tiere & Tierbedarf
fr: Animaux et articles pour animaux de compagnie
...
wikidata:en: Q116957923

< en: Animals & Pet Supplies

en: Pet Supplies
...
wikidata:en: Q115921084
```

## Data Sources

- **Google Product Taxonomy**: https://raw.githubusercontent.com/lubianat/google_product_taxonomy_reference/refs/heads/master/data/taxonomy.json
- **Google Translations**: https://www.google.com/basepages/producttype/
- **Wikidata**: https://query.wikidata.org/ (property P11302)
- **Current OPF Taxonomy**: taxonomies/product/categories.txt

## Known Limitations

1. **Large Size**: 5,595 categories (vs 136 current) - may need filtering for OPF use
2. **Encoding Issues**: Some Google source files have Latin-1 encoding
3. **Missing Categories**: Some OPF-specific categories (e.g., "Smartphones" subcategories) not in Google taxonomy
4. **Basic Matching**: Simple string matching may miss some existing data correlations

See USAGE_GUIDE.md for details and solutions.

## Next Steps

1. Review generated taxonomy
2. Filter categories relevant to Open Products Facts
3. Enhance with OPF-specific subcategories
4. Test with sample products
5. Plan migration from current taxonomy

See IMPLEMENTATION_CHECKLIST.md for full deployment guide.

## Contributing

To improve the conversion:
- Enhance category matching algorithms
- Add more language translations
- Improve filtering logic
- Add validation checks

## License

Part of Open Products Facts - AGPL-3.0 license

## Support

- Documentation: See USAGE_GUIDE.md
- Issues: GitHub issue tracker
- Questions: Open Products Facts community
