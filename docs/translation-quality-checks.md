# Translation Quality Checks

This document describes the translation quality checks performed by the `check-translation-quality.py` script and the GitHub Actions workflow.

## Overview

The translation quality checker helps maintain high-quality translations for Open Food Facts by automatically detecting common translation mistakes before they are merged into production.

## Checks Performed

### 1. Brand Names Must Not Be Translated

**What it checks:** Ensures that brand names and product names are kept in their original form.

**Brand names that must NOT be translated:**
- Open Food Facts
- Open Beauty Facts
- Open Pet Food Facts
- Open Prices
- Green-Score
- Nutri-Score
- NutriScore
- Nova

**Why:** These are proper nouns and brand names that must remain consistent across all languages for brand recognition and legal reasons.

**Example of incorrect translation:**
```po
# ❌ WRONG - Norwegian
msgid "Open Food Facts"
msgstr "åpne matfakta"

# ✅ CORRECT - Norwegian
msgid "Open Food Facts"
msgstr "Open Food Facts"
```

**Example of incorrect translation:**
```po
# ❌ WRONG - Portuguese
msgid "Green-Score"
msgstr "Pontuação Verde"

# ✅ CORRECT - Portuguese
msgid "Green-Score"
msgstr "Green-Score"
```

### 2. Placeholder Consistency

**What it checks:** Ensures that format placeholders like `%s`, `%d`, `%i` are preserved correctly in translations.

**Why:** These placeholders are replaced with actual values at runtime. Changing, removing, or adding placeholders will cause display errors or crashes.

**Example of incorrect placeholder:**
```po
# ❌ WRONG - Wrong placeholder type
msgid "Page %d"
msgstr "Strona %s"  # Should be %d, not %s

# ✅ CORRECT
msgid "Page %d"
msgstr "Strona %d"
```

**Example of missing placeholder:**
```po
# ❌ WRONG - Placeholder count mismatch
msgid "%d products match the search criteria, of which %i products have a known production place."
msgstr "%s produktów odpowiada kryteriom wyszukiwania, miejsce produkcji jest znane dla %s z nich."
# Two %i/%d in source but two %s in translation

# ✅ CORRECT
msgid "%d products match the search criteria, of which %i products have a known production place."
msgstr "%d produktów odpowiada kryteriom wyszukiwania, z których %i ma znane miejsce produkcji."
```

### 3. HTML Tag Consistency

**What it checks:** Ensures that HTML tags are preserved and balanced in translations.

**Why:** HTML tags provide structure and styling. Missing or extra tags will break the display.

**Example of incorrect HTML:**
```po
# ❌ WRONG - Extra HTML tag
msgid "with nutrition facts"
msgstr "avec informations<br/>nutritionnelles"
# Added <br/> tag that doesn't exist in source

# ✅ CORRECT
msgid "with nutrition facts"
msgstr "avec informations nutritionnelles"
```

**Example of unbalanced tags:**
```po
# ❌ WRONG - Unbalanced anchor tags
msgid "Please e-mail <a href=\"mailto:producers@openfoodfacts.org\">producers@openfoodfacts.org</a>"
msgstr "请通过e-mail <a href=\"mailto:producers@openfoodfacts.org\">producers@openfoodfacts.org</a><a href=\"mailto:producers@openfoodfacts.org\">"
# Extra opening <a> tag

# ✅ CORRECT
msgid "Please e-mail <a href=\"mailto:producers@openfoodfacts.org\">producers@openfoodfacts.org</a>"
msgstr "请通过e-mail <a href=\"mailto:producers@openfoodfacts.org\">producers@openfoodfacts.org</a>"
```

### 4. URL Language Code Consistency

**What it checks:** Ensures that URLs with language codes match the target translation language.

**Why:** Users should be directed to the version of the website in their own language.

**Example of incorrect URL:**
```po
# ❌ WRONG - French translation using Portuguese URL
msgid "https://world.openfoodfacts.org"
msgstr "https://world-pt.openfoodfacts.org"  # In a French (fr.po) file

# ✅ CORRECT - French translation using French URL
msgid "https://world.openfoodfacts.org"
msgstr "https://world-fr.openfoodfacts.org"  # In a French (fr.po) file
```

## How to Fix Issues

### If you are a translator on Crowdin:

1. Log in to [Crowdin](https://translate.openfoodfacts.org)
2. Find the string mentioned in the error
3. Fix the translation according to the guidelines above
4. Save your changes

### If you are a developer:

1. Review the errors reported by the CI check
2. If there are issues in the `.po` files that need immediate fixing:
   - Edit the affected `.po` file directly
   - Run `python3 scripts/check-translation-quality.py --file <file>` to verify
   - Commit the fix
3. For long-term fixes, update the source string or add a translator comment in the `.pot` file

## Running Checks Locally

### Check all translation files:
```bash
python3 scripts/check-translation-quality.py
```

### Check a specific file:
```bash
python3 scripts/check-translation-quality.py --file po/common/fr.po
```

### Generate PR comments (for changed files only):
```bash
python3 scripts/generate-translation-pr-comments.py
```

## Advanced Checks with translate-toolkit

The workflow also uses `pofilter` from translate-toolkit to perform additional checks:

- **accelerators**: Checks keyboard accelerators are consistent
- **escapes**: Checks escape sequences are valid
- **newlines**: Checks newline consistency
- **tabs**: Checks tab character consistency  
- **urls**: Checks URL consistency
- **variables**: Checks variable placeholders
- **xmltags**: Checks XML/HTML tag validity

To run these checks locally:
```bash
# Install translate-toolkit
pip install translate-toolkit

# Run checks on a file
pofilter -t urls -t variables -t xmltags po/common/fr.po /tmp/output.po
```

## GitHub Actions Integration

The translation quality checks run automatically on:
- **Pull Requests** that modify `.po` or `.pot` files
- **Pushes** to the `main` branch

The workflow will:
1. Validate basic format with `msgfmt` (existing check)
2. Run comprehensive quality checks with our Python script
3. Run additional checks with `pofilter` from translate-toolkit
4. Generate a comment on PRs summarizing any issues found

## Adding New Checks

To add a new quality check:

1. Add a new method to the `TranslationQualityChecker` class in `scripts/check-translation-quality.py`
2. Call it from the `check_all()` method
3. Create `TranslationIssue` objects for any problems found
4. Add documentation here explaining the new check
5. Test it on existing files

## References

- [GNU gettext documentation](https://www.gnu.org/software/gettext/manual/html_node/index.html)
- [Translate Toolkit documentation](https://docs.translatehouse.org/projects/translate-toolkit/)
- [Crowdin Translation Guide](https://support.crowdin.com/)
