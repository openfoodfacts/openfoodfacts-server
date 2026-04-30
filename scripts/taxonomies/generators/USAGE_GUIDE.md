# Google Product Taxonomy to OPF Categories - Usage Guide

## Overview

This directory contains a complete pipeline to convert Google Product Taxonomy into the Open Products Facts category taxonomy format. The scripts have been successfully tested and can generate a taxonomy with **5,595 categories** and **5,593 Wikidata mappings**.

## Quick Start

```bash
cd scripts/taxonomies/generators
python3 00_run_all.py
```

This will:
1. Download Google Product Taxonomy (hierarchical structure + translations in 15 languages)
2. Query Wikidata for category mappings (5,599 mappings available)
3. Extract data from existing OPF categories.txt (wikidata, carbon impact, etc.)
4. Generate new_categories.txt with merged data

**Output**: `google_product_taxonomy_data/new_categories.txt` (~3MB, 112k lines)

## What Gets Generated

The generated taxonomy includes:

### Translations
- **15 languages**: English, French, German, Spanish, Italian, Dutch, Portuguese, Czech, Danish, Japanese, Norwegian, Polish, Russian, Swedish, Turkish
- Multiple synonyms per language where available
- Hierarchical parent-child relationships preserved

### Wikidata Integration
- 5,593 Google Product Categories have Wikidata Q-IDs
- Multilingual labels from Wikidata (10 languages)
- Direct mapping via Wikidata property P11302

### Preserved Data
From existing OPF taxonomy:
- Carbon impact data (51 categories with ImpactCO2.fr data)
- Additional translations
- Custom properties
- Unit names

## Example Output

```text
en: Animals & Pet Supplies
xx: Animals & Pet Supplies
cs: Chovatelství
da: Dyr og tilbehør til kæledyr
de: Tiere & Tierbedarf
es: Productos para mascotas y animales
fr: Animaux et articles pour animaux de compagnie
it: Articoli per animali
ja: ペット・ペット用品
nl: Dieren
no: Dyr og kjæledyrutstyr
pl: Zwierzęta i artykuły dla zwierząt
pt: Animais e suprimentos para animais de estimação
ru: Животные и товары для питомцев
sv: Djur och tillbehör till husdjur
tr: Hayvanlar ve Evcil Hayvan Ürünleri
wikidata:en: Q116957923

< en: Animals & Pet Supplies

en: Pet Supplies
...
```

## Script Details

### 01_fetch_google_product_taxonomy.py
- Fetches hierarchical JSON structure
- Downloads translations from 19 locale-specific URLs
- Handles encoding issues (Latin-1 vs UTF-8)
- **Output**: `taxonomy_structure.json`, `translations.json`

### 02_fetch_wikidata_mappings.py
- Queries Wikidata SPARQL endpoint
- Fetches multilingual labels for all mapped entities
- Uses property P11302 (Google Product Category ID)
- **Output**: `wikidata_mappings.json`, `wikidata_labels.json`

### 03_extract_existing_data.py
- Parses current `taxonomies/product/categories.txt`
- Extracts wikidata IDs, carbon impact, properties
- Handles complex taxonomy format with properties containing numbers
- **Output**: `existing_*.json` files

### 04_generate_opf_taxonomy.py
- Merges all data sources
- Generates OPF taxonomy format
- Attempts fuzzy matching with existing categories
- Preserves carbon impact and custom properties
- **Output**: `new_categories.txt`

## Data Sources

### Google Product Taxonomy
- **Primary**: https://raw.githubusercontent.com/lubianat/google_product_taxonomy_reference/refs/heads/master/data/taxonomy.json
- **Translations**: https://www.google.com/basepages/producttype/taxonomy-with-ids.{locale}.txt
- **Version**: 2021-09-21 (as of last check)
- **Total Categories**: 5,595

### Wikidata
- **SPARQL Endpoint**: https://query.wikidata.org/sparql
- **Property**: P11302 (Google Product Category ID)
- **Mapped Entities**: 5,599 (some duplicates exist)
- **Coverage**: ~99.9% of Google Product Taxonomy

### Current OPF Taxonomy
- **File**: `taxonomies/product/categories.txt`
- **Categories**: 136
- **With Wikidata**: 9
- **With Carbon Impact**: 51

## Known Issues and Limitations

### 1. Encoding Issues in Source Data
Some Google translation files have encoding problems (Latin-1 instead of UTF-8). The script attempts to handle this, but some characters may still appear incorrectly.

**Affected languages**: Portuguese, Czech, Danish, Swedish, Turkish

**Solution**: The script tries UTF-8 first, then falls back to Latin-1. You may need to manually review and fix affected entries.

### 2. Size of Generated Taxonomy
The generated file is very large (3MB, 112k lines) compared to the current taxonomy (136 categories).

**Considerations**:
- Google Product Taxonomy covers ALL products, not just those relevant to Open Products Facts
- You may want to filter categories to only include relevant ones
- Consider creating separate taxonomies by product type

### 3. Missing Smartphone Category
Google Product Taxonomy doesn't have a standalone "Smartphones" category. Instead, mobile phones are under:
- "Electronics > Communications > Telephony > Mobile Phones"
- "MP3 Player & Mobile Phone Accessory Sets" (accessories)

**Note**: The current OPF taxonomy has granular subcategories (Android smartphones, iPhone smartphones) that don't exist in Google's taxonomy.

### 4. Fuzzy Matching Limitations
The automatic matching between existing OPF categories and Google categories is basic (normalized string comparison). Many matches may be missed.

**Recommendation**: Manual review and adjustment of category mappings.

## Customization

### Filtering Categories
To generate a smaller taxonomy with only relevant categories, modify `04_generate_opf_taxonomy.py`:

```python
# Add filtering logic in generate_taxonomy()
RELEVANT_ROOT_CATEGORIES = ['1', '166', '356', ...]  # Specific category IDs

def should_include_category(cat_id: str, data: Dict) -> bool:
    # Add your filtering logic here
    return cat_id in RELEVANT_ROOT_CATEGORIES or data.get('parent_id') in RELEVANT_ROOT_CATEGORIES
```

### Adding More Languages
Edit `LANGUAGE_URLS` in `01_fetch_google_product_taxonomy.py`:

```python
LANGUAGE_URLS = {
    # ... existing entries ...
    'ar-AR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.ar.txt',
    'zh-CN': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.zh-CN.txt',
}
```

### Improving Category Matching
Edit `find_matching_existing_category()` in `04_generate_opf_taxonomy.py` to implement:
- Levenshtein distance for fuzzy matching
- Machine learning-based matching
- Manual mapping file

## Testing and Validation

### Verify Generated File
```bash
# Check file size and line count
ls -lh google_product_taxonomy_data/new_categories.txt
wc -l google_product_taxonomy_data/new_categories.txt

# Sample categories
head -100 google_product_taxonomy_data/new_categories.txt
grep -A10 "Animals & Pet Supplies" google_product_taxonomy_data/new_categories.txt

# Check wikidata integration
grep "wikidata:en:" google_product_taxonomy_data/new_categories.txt | wc -l
```

### Validate Taxonomy Format
If taxonomy validation scripts exist in the repository:
```bash
# Run taxonomy tests
cd ../../..  # Back to repo root
# Add appropriate test commands here
```

## Deployment

### Manual Review Required
Before deploying, you should:

1. **Review Sample Categories**
   - Check that translations are correct
   - Verify Wikidata mappings make sense
   - Ensure hierarchy is logical

2. **Test with a Subset**
   - Start with a filtered taxonomy
   - Test with actual product data
   - Gather feedback from community

3. **Plan Migration**
   - Existing products may have categories that don't exist in new taxonomy
   - Need to map old categories to new ones
   - Consider maintaining both taxonomies temporarily

### Deployment Steps

```bash
# 1. Backup current taxonomy
cp taxonomies/product/categories.txt taxonomies/product/categories.txt.backup

# 2. Review and edit the generated file as needed
# Edit google_product_taxonomy_data/new_categories.txt

# 3. Copy to production location
cp scripts/taxonomies/generators/google_product_taxonomy_data/new_categories.txt taxonomies/product/categories.txt

# 4. Rebuild taxonomy indexes (if needed)
# Add appropriate build commands

# 5. Test with sample products
# Add appropriate test commands

# 6. Deploy
# Follow your normal deployment process
```

## Maintenance

### Updating Google Product Taxonomy
Google updates their taxonomy periodically. To update:

```bash
# Re-fetch all data
cd scripts/taxonomies/generators
rm -rf google_product_taxonomy_data/*.json
python3 00_run_all.py
```

### Updating Wikidata Mappings
Wikidata mappings grow over time:

```bash
# Re-fetch just Wikidata data
python3 02_fetch_wikidata_mappings.py
python3 04_generate_opf_taxonomy.py
```

### Adding Carbon Impact Data
To add new carbon impact data:

1. Update `taxonomies/product/categories.txt` with new carbon impact entries
2. Run `python3 03_extract_existing_data.py`
3. Run `python3 04_generate_opf_taxonomy.py`

## Troubleshooting

### "requests module not found"
```bash
pip install requests
```

### "Required file not found"
Make sure to run scripts in order, or run `00_run_all.py`

### "Network timeout"
- Increase timeout in script
- Run individual scripts with retries
- Use cached data: `python3 00_run_all.py --skip-fetch`

### "Encoding errors"
This is a known issue with Google's source files. The script attempts to handle it, but manual review may be needed.

## Performance

- **Total execution time**: ~5-10 minutes (depending on network speed)
- **Wikidata queries**: Most time-consuming (batched in groups of 100)
- **File generation**: Fast (<1 minute)
- **Disk space**: ~7MB for all data files

## Future Improvements

1. **Better Matching Algorithm**
   - Use NLP/ML for category matching
   - Implement manual mapping file for edge cases

2. **Category Filtering**
   - Add product-type specific filters
   - Allow exclusion patterns

3. **Incremental Updates**
   - Detect changes in source taxonomies
   - Only update modified categories

4. **Validation**
   - Add format validation
   - Check for circular dependencies
   - Verify Wikidata IDs exist

5. **Alternative Sources**
   - Support other product taxonomies
   - Merge multiple taxonomy sources

## Support

For issues, questions, or contributions:
- Open an issue on the Open Products Facts GitHub repository
- Check the main README_GPC_CONVERSION.md for more details
- Review generated files in `google_product_taxonomy_data/`

## License

These scripts are part of Open Products Facts and follow the AGPL-3.0 license.
