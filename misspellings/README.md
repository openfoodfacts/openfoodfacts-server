# Misspellings Directory

This directory contains files for correcting common misspellings in product data.

## File Format

Each file contains one misspelling correction per line:

    lc:misspelled -> correct

- `lc:` is a 2-letter language code, or `xx` for all languages
- The replacement is case-insensitive, but preserves the original case of the source text
If the replacement has mixed case (e.g. for some brands), it is used as-is.
- Lines starting with `#` are comments

## Data Files

| File | Purpose |
|------|---------|
| `ingredients_misspellings.txt` | Misspellings in ingredient lists |
| `brands_misspellings.txt` | Misspellings in product brand names |

## Which Misspellings to Add

**BEFORE adding an entry, verify that the correction is 100% correct in all cases.**

Only add misspellings that are:
- Common (observed many times in real product data)
- Unambiguously correct (the misspelled form can never be intended)

Do NOT add:
- Rare misspellings (only seen a few times): the corresponding product should be corrected manually instead
- Ambiguous corrections (where the misspelled form could be a valid spelling in another word)
