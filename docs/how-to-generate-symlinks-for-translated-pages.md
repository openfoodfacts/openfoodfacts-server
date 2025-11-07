# Generating Symlinks for Translated Page Names

This document explains how to use the `generate_symlinks_for_translated_pages.py` script to create symlinks for translated page names in the openfoodfacts-web repository.

## Overview

The script extracts all link translations from `.po` files in the `po/common/` directory and generates shell commands to create symlinks for translated page names. This allows users to access pages using translated URLs that redirect to the canonical English page names.

## What does it do?

The script:

1. Parses all `.po` files in `po/common/` directory
2. Finds all `msgctxt` entries ending with `_link` (e.g., `footer_press_link`, `menu_discover_link`)
3. Extracts the English page name (`msgid`) and translated page name (`msgstr`)
4. Generates symlink commands for each language and product database variant (OFF, OPF, OBF, OPFF)

## Symlink Pattern

For each translated page, symlinks are created in the following pattern:

```
lang/xx/texts/translated_pagename.html -> pagename.html
lang/opf/xx/texts/translated_pagename.html -> pagename.html
lang/obf/xx/texts/translated_pagename.html -> pagename.html
lang/opff/xx/texts/translated_pagename.html -> pagename.html
```

Where:
- `xx` is the language code (e.g., `fr`, `de`, `es`)
- `pagename` is the English page name (from `msgid`, without leading `/`)
- `translated_pagename` is the translated page name (from `msgstr`, without leading `/`)

## Usage

### Generate symlinks to stdout

```bash
python3 scripts/generate_symlinks_for_translated_pages.py
```

This will print the shell commands to create all symlinks to stdout.

### Generate symlinks to a file

```bash
python3 scripts/generate_symlinks_for_translated_pages.py --output create_symlinks.sh
```

This will write the shell commands to `create_symlinks.sh`.

### Execute the generated script

Once you have the script file, you can execute it in the openfoodfacts-web repository:

```bash
# Clone or navigate to openfoodfacts-web repository
cd /path/to/openfoodfacts-web

# Copy the generated script
cp /path/to/openfoodfacts-server/create_symlinks.sh .

# Make it executable and run it
chmod +x create_symlinks.sh
./create_symlinks.sh
```

## Examples

### French translations

For the French language (`fr`), the script generates symlinks like:

```bash
mkdir -p lang/fr/texts
ln -sf discover.html lang/fr/texts/decouvrir.html
ln -sf contribute.html lang/fr/texts/contribuer.html
ln -sf press.html lang/fr/texts/presse.html
ln -sf partners.html lang/fr/texts/partenaires.html
```

### German translations

For the German language (`de`), the script generates symlinks like:

```bash
mkdir -p lang/de/texts
ln -sf partners.html lang/de/texts/partner.html
ln -sf press.html lang/de/texts/press-and-blogs.html
```

## Extracted Link Types

The script extracts all links from the following `msgctxt` entries:

- `menu_discover_link` - /discover
- `menu_contribute_link` - /contribute
- `footer_press_link` - /press
- `footer_partners_link` - /partners
- `footer_code_of_conduct_link` - /code-of-conduct
- `footer_legal_link` - /legal
- `footer_privacy_link` - /privacy
- `footer_terms_link` - /terms-of-use
- `footer_who_we_are_link` - /who-we-are
- And many more...

## Technical Details

### Filtering

The script only processes:
- Local page links (starting with `/`)
- Translations that differ from the English page name
- Paths without special characters (`%`, `?`, `&`, `=`, spaces)

This filters out:
- External URLs (e.g., `https://...`)
- Placeholder strings (e.g., "Permanent link to...")
- Untranslated entries

### Parser

The script includes a simple `.po` file parser that:
- Reads `msgctxt`, `msgid`, and `msgstr` entries
- Handles multiline strings
- Filters for entries with `msgctxt` ending in `_link`

## Notes

- The script automatically skips English (`en`) as it's the base language
- Only creates symlinks for translations that differ from the original page name
- The generated script includes `mkdir -p` commands to ensure directories exist before creating symlinks
