#!/usr/bin/env python3
"""
Open Food Facts - Forbidden Words Quality Scanner
Detects insults, vulgarities, slurs, and vandalism in Open Food Facts data exports (Parquet or CSV/TSV).

Features:
    - Zero obscenities in git: loads word lists from uncommitted local conf/forbidden_words.txt
      or fetches them via `python3 scripts/update_forbidden_words.py`.
    - Fully configurable allow list from conf/forbidden_words_allowlist.txt:
        * Product barcodes of real novelty/colloquial products (bypasses detection).
        * Allowed patterns and phrases (cacao, spotted dick, cornichon, fucking delicious, etc.).
        * Country/language rules (e.g. 'pute' allowed in Germany/Austria/Switzerland).
    - Streaming processing for multi-gigabyte Parquet, CSV, TSV, or GZ exports with low memory footprint.

Usage:
    # Scan a local Parquet export:
    python3 scripts/detect_forbidden_words.py --input food.parquet --output issues.csv

    # Scan an Open Food Facts gzipped CSV/TSV export:
    python3 scripts/detect_forbidden_words.py --input en.openfoodfacts.org.products.csv.gz --output issues.csv

    # Scan from stdin (e.g. streaming download or pipe):
    gzip -dc en.openfoodfacts.org.products.csv.gz | python3 scripts/detect_forbidden_words.py -i - -o issues.csv

    # Scan with limit for a quick dry-run:
    python3 scripts/detect_forbidden_words.py --input food.parquet --limit 50000

    # Custom allowlist:
    python3 scripts/detect_forbidden_words.py -i food.parquet -a conf/forbidden_words_allowlist.txt
"""

import argparse
import csv
import gzip
import os
from pathlib import Path
import re
import sys
import time
import unicodedata
from typing import Dict, Generator, List, Optional, Set, Tuple

# Expand maximum CSV field size to handle large ingredient or OCR text fields
try:
    csv.field_size_limit(sys.maxsize)
except OverflowError:
    csv.field_size_limit(2147483647)

# Neutral fallback placeholders - actual obscenities are NEVER committed in this file.
# Run 'python3 scripts/update_forbidden_words.py' to populate conf/forbidden_words.txt.
DEFAULT_FORBIDDEN_WORDS = {
    "xx": ["test_vandalism_placeholder", "test_slur_placeholder"],
    "fr": ["test_insulte_fr", "test_vulgarite_fr"],
    "en": ["test_insult_en", "test_profanity_en"],
    "es": ["test_insult_es"],
    "de": ["test_insult_de"],
    "it": ["test_insult_it"],
}

# Diacritics and character substitutions mapping
ACCENT_MAP = {
    "ss": "(?:ss|ß)",
    "a": "[aàáâãäåAÀÁÂÃÄÅ]",
    "e": "[eèéêëEÈÉÊË]",
    "i": "[iìíîïIÌÍÎÏ]",
    "o": "[oòóôõöOÒÓÔÕÖ]",
    "u": "[uùúûüUÙÚÛÜ]",
    "c": "[cçCÇ]",
    "n": "[nñNÑ]",
}


def unaccent(s: Optional[str]) -> str:
    """Normalize and strip combining accents from a string."""
    if not s:
        return ""
    nfkd = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).lower()


def canonical_key(s: str) -> str:
    """Produce a canonical key for word lookup (unaccented, normalized spaces)."""
    clean = unaccent(s)
    clean = clean.replace("œ", "oe").replace("ß", "ss")
    return re.sub(r"[\s\-_]+", " ", clean).strip()


def word_to_pattern(word: str) -> str:
    """Convert a forbidden word or phrase into a regex pattern matching accent variations."""
    tokens = [t for t in re.split(r"[\s\-_]+", word.strip()) if t]
    tokens_patterns = []
    for tok in tokens:
        chars = []
        i = 0
        while i < len(tok):
            if tok[i:i + 2].lower() == "ss":
                chars.append("(?:ss|ß)")
                i += 2
                continue
            ch = tok[i].lower()
            chars.append(ACCENT_MAP.get(ch, re.escape(ch)))
            i += 1
        tokens_patterns.append("".join(chars))
    return r"[\s\-_]+".join(tokens_patterns)


def load_forbidden_words(conf_path: Optional[str] = None) -> Dict[str, List[str]]:
    """Load forbidden words from conf file or fall back to defaults."""
    words_by_lang: Dict[str, List[str]] = {}

    target_path = conf_path
    if not target_path:
        repo_conf = Path(__file__).resolve().parent.parent / "conf" / "forbidden_words.txt"
        if repo_conf.is_file():
            target_path = str(repo_conf)
        elif os.environ.get("PRODUCT_OPENER_DIR"):
            env_conf = Path(os.environ["PRODUCT_OPENER_DIR"]) / "conf" / "forbidden_words.txt"
            if env_conf.is_file():
                target_path = str(env_conf)

    if target_path and os.path.isfile(target_path):
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    m = re.match(r"^([a-z]{2}):\s*(.+)$", line, re.IGNORECASE)
                    if m:
                        lang = m.group(1).lower()
                        word = m.group(2).strip()
                        if word:
                            words_by_lang.setdefault(lang, []).append(word)
        except Exception as e:
            sys.stderr.write(f"Warning: could not read {target_path} ({e}), using default word list.\n")

    if not words_by_lang:
        words_by_lang = {k: list(v) for k, v in DEFAULT_FORBIDDEN_WORDS.items()}

    return words_by_lang


def load_allowlist(allowlist_path: Optional[str] = None) -> Tuple[Set[str], Set[str], Dict[str, List[str]]]:
    """
    Load allowlist containing:
      - allowed_barcodes: Set of product barcodes to ignore completely
      - allowed_patterns: Set of phrases/patterns to allow
      - country_rules: Dict of word -> list of country codes/languages where allowed
    """
    allowed_barcodes: Set[str] = set()
    allowed_patterns: Set[str] = set()
    country_rules: Dict[str, List[str]] = {
        "pute": ["de", "germany", "allemagne", "deutschland", "en:germany", "en:austria", "en:switzerland", "at", "ch"]
    }

    target = allowlist_path
    if not target:
        repo_allow = Path(__file__).resolve().parent.parent / "conf" / "forbidden_words_allowlist.txt"
        if repo_allow.is_file():
            target = str(repo_allow)
        elif os.environ.get("PRODUCT_OPENER_DIR"):
            env_allow = Path(os.environ["PRODUCT_OPENER_DIR"]) / "conf" / "forbidden_words_allowlist.txt"
            if env_allow.is_file():
                target = str(env_allow)

    if target and os.path.isfile(target):
        try:
            current_section = None
            with open(target, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if line.startswith("[") and line.endswith("]"):
                        current_section = line[1:-1].strip().lower()
                        continue

                    # Strip trailing comment
                    val = line.split("#")[0].strip()
                    if not val:
                        continue

                    if current_section == "barcodes":
                        allowed_barcodes.add(val)
                    elif current_section == "patterns":
                        clean_pat = canonical_key(val)
                        if clean_pat:
                            allowed_patterns.add(clean_pat)
                    elif current_section == "country_rules":
                        if ":" in val:
                            w, countries_str = val.split(":", 1)
                            w_norm = canonical_key(w)
                            ctries = [c.strip().lower() for c in countries_str.split(",") if c.strip()]
                            country_rules[w_norm] = ctries
        except Exception as e:
            sys.stderr.write(f"Warning: could not read allowlist {target}: {e}\n")

    return allowed_barcodes, allowed_patterns, country_rules


class ForbiddenWordsDetector:
    """Compiled forbidden words matcher with configurable allowlist and false-positive guards."""

    def __init__(
        self,
        words_by_lang: Dict[str, List[str]],
        allowed_barcodes: Optional[Set[str]] = None,
        allowed_patterns: Optional[Set[str]] = None,
        country_rules: Optional[Dict[str, List[str]]] = None,
        all_languages: bool = False
    ):
        self.words_by_lang = words_by_lang
        self.allowed_barcodes = allowed_barcodes or set()
        self.allowed_patterns = allowed_patterns or set()
        self.country_rules = country_rules or {}
        self.all_languages = all_languages
        self.compiled_regexes: Dict[str, re.Pattern] = {}
        self.canonical_words_set: Set[str] = set()

        for lang, words in words_by_lang.items():
            for w in words:
                self.canonical_words_set.add(canonical_key(w))

        all_langs = list(words_by_lang.keys())
        for lang in all_langs:
            self._compile_for_lang(lang)

        all_words: Set[str] = set()
        for words in words_by_lang.values():
            all_words.update(words)
        sorted_all = sorted(all_words, key=lambda w: len(w), reverse=True)
        patterns_all = [word_to_pattern(w) for w in sorted_all]
        self.all_langs_pattern = re.compile(
            r"\b(?:" + "|".join(patterns_all) + r")\b",
            re.IGNORECASE
        )

    def _compile_for_lang(self, lang: str) -> re.Pattern:
        if lang in self.compiled_regexes:
            return self.compiled_regexes[lang]

        words_set: Set[str] = set()
        for cat in ("xx", "en", lang):
            if cat in self.words_by_lang:
                words_set.update(self.words_by_lang[cat])

        sorted_words = sorted(words_set, key=lambda w: len(w), reverse=True)
        patterns = [word_to_pattern(w) for w in sorted_words]
        pat = re.compile(
            r"\b(?:" + "|".join(patterns) + r")\b",
            re.IGNORECASE
        )
        self.compiled_regexes[lang] = pat
        return pat

    def get_pattern(self, lang: Optional[str]) -> re.Pattern:
        if self.all_languages:
            return self.all_langs_pattern
        lang_code = (lang or "en").lower()[:2]
        return self._compile_for_lang(lang_code)

    def is_false_positive(
        self,
        word_key: str,
        match_text: str,
        full_text: str,
        start: int,
        end: int,
        lang: Optional[str] = None,
        countries: Optional[str] = None,
        code: Optional[str] = None
    ) -> bool:
        """Filter out legitimate culinary, agricultural, bilingual, or allowlisted patterns."""
        # Check country-specific rule (e.g. 'pute' in Germany / German language)
        if word_key in self.country_rules:
            l_code = (lang or "").lower()
            c_str = (countries or "").lower()
            for allowed_region in self.country_rules[word_key]:
                if l_code == allowed_region or allowed_region in c_str:
                    return True

        # Check surrounding text for configured allowlist patterns
        window_start = max(0, start - 35)
        window_end = min(len(full_text), end + 35)
        surrounding = canonical_key(full_text[window_start:window_end])
        clean_surrounding = re.sub(r"[^\w\s]", " ", surrounding)
        clean_surrounding = re.sub(r"\s+", " ", clean_surrounding).strip()
        padded_surrounding = f" {clean_surrounding} "
        for pat in self.allowed_patterns:
            if f" {pat} " in padded_surrounding:
                return True

        # English 'bite' or German 'bitte'
        if word_key in ("bite", "bitte"):
            after = full_text[end:end + 12].lower()
            if re.match(r"^[\s\-]?size\b", after):
                return True
            surr = full_text[max(0, start - 25):min(len(full_text), end + 35)].lower()
            if any(g in surr for g in ("schutteln", "schütteln", "wenden", "danke", "vor dem offnen")):
                return True

        # French 'cul' in legitimate culinary phrases
        if word_key == "cul":
            after = full_text[end:end + 30].lower()
            if re.match(r"^[\s\-']*(?:d'artichauts?|artichauts?|noir|noire|noirs|noires|de veau|de poule)\b", after):
                return True

        # French 'P'tit' / 'P'tits' (e.g. P'tit Déli, P'tits Amoureux, P’tit Québec)
        if word_key in ("tit", "tits"):
            before = full_text[max(0, start - 6):start].lower()
            if re.search(r"p[\s'’\-]+$", before):
                return True

        # Brand exemptions: Gerber baby food, Cock brand
        if word_key == "gerber":
            return True
        if word_key == "cock":
            clean_brand = canonical_key(full_text)
            if clean_brand in ("cock", "cock brand", "cock mint", "cock flavour soup"):
                return True

        # English 'Ass.' or 'Ass'n' (abbreviation for Association)
        if word_key == "ass":
            after = full_text[end:end + 5].lower()
            if after.startswith((".", "'n", "’n")):
                return True

        # 'retard' in legitimate food preservative or functional descriptions (e.g. "potassium sorbate [to retard spoilage]")
        if word_key in ("retard", "retards"):
            if re.search(r"\b(?:to retard|retards? (?:spoilage|staling|oxidation|mold|mould|growth|decay|fermentation)|flame retardant|fire retardant)\b", clean_surrounding):
                return True
            if re.search(r"\b(?:retarder|retardateur)\b", clean_surrounding):
                return True

        # French 'râpé' (grated), Spanish 'rape' (monkfish), Italian 'rape' (beets) or English 'rapeseed'
        if word_key in ("rape", "rapes", "rapee", "rapees"):
            if "â" in match_text.lower() or "à" in match_text.lower() or "è" in match_text.lower() or "é" in match_text.lower():
                return True
            if (lang or "").lower() in ("fr", "fra", "french", "es", "spa", "spanish", "it", "ita", "italian"):
                return True
            if any(c in (countries or "").lower() for c in ("france", "spain", "espagne", "espana", "italy", "italie", "italia")):
                return True
            after = full_text[end:end + 15].lower()
            if after.startswith(("seed", " oil", "-seed")):
                return True
            if any(o in clean_surrounding for o in ("oil", "fat", "vegetable", "hydrogenated", "sunflower", "palm", "seed", "margarine", "colza", "cabeza", "caldo", "pescado", "monkfish")):
                return True

        # Spanish/Italian preposition 'con' (with) or French OCR artifacts
        if word_key == "con":
            if (lang or "").lower() in ("es", "it", "pt", "ca", "gl") or any(c in clean_surrounding for c in ("carne", "leche", "tomate", "queso", "arroz", "pollo", "aceite", "chispas", "sabor", "chilli")):
                return True
            if any(w in clean_surrounding for w in ("contenant", "conservateur", "conserve", "conserver", "concentre")):
                return True

        # 'cum' in ingredients (OCR of gum, cumin, Latin botanical names)
        if word_key == "cum":
            if any(g in clean_surrounding for g in ("guar", "xanthan", "bean", "acacia", "cellulose", "arabic", "locust", "gellan", "tara", "chewing", "bubble", "thickener")):
                return True
            if any(sp in clean_surrounding for sp in ("spice", "epice", "épice", "coriander", "paprika", "cannelle", "cardamome", "carotte", "chiche", "cumin")):
                return True
            if any(b in clean_surrounding for b in ("basilicum", "ceylanicum", "capsicum", "cuminum", "celticum", "orthophosphoric", "vitamin")):
                return True

        # 'butt' in ingredients (OCR of butter, pork cuts, BBQ rubs)
        if word_key == "butt":
            if any(b in clean_surrounding for b in ("peanut", "cocoa", "almond", "milk", "apple", "pork", "shoulder", "boston", "unsalted", "rub", "dust", "bad byron", "corn syrup", "syrup", "solids", "pancake", "waffle", "whey", "peppers")):
                return True

        # 'spic' in ingredients (truncated OCR of spices)
        if word_key == "spic":
            if any(s in clean_surrounding for s in ("salt", "garlic", "onion", "pepper", "sauce", "powder", "glutamate", "chloride", "flavor", "flavour", "antioxidant", "citric", "acid", "gum", "xanthan", "sorbate", "sugar", "vinegar", "oil")):
                return True

        # 'anal' in ingredients (OCR of analyse nutritionnelle)
        if word_key == "anal":
            if any(a in clean_surrounding for a in ("se", "use", "isis", "nutrition", "mo enne", "moyenne", "100g", "valeur", "de worm", "worm")):
                return True

        # 'caca' in ingredients (OCR of cacao)
        if word_key == "caca":
            if any(c in clean_surrounding for c in ("beurre", "pate", "pâte", "manteca", "burro", "maigre", "poudre", "chocolat", "noir", "solide", "amargo", "caramel", "creme", "crème", "vanille", "coco", "ingrediente", "fondente", "pasta", "cioccolato", "blanche", "lait")):
                return True

        # 'cock' in Thai Cock Brand or food contexts
        if word_key == "cock":
            if code and (code.startswith("0084909") or code.startswith("8851918")):
                return True
            if any(c in clean_surrounding for c in ("boisson", "ananas", "haricot", "mungo", "chantaboon", "rice stick", "tranche", "grace", "caribbean", "soup", "cola", "sauce", "chilli", "seasoning")):
                return True

        # 'poon' in OCR (spoon / boon tot kopje)
        if word_key == "poon":
            if any(p in clean_surrounding for p in ("spoon", "kopje", "boon", "heaped", "teaspoon", "tablespoon", "portion", "porcion", "pasta")):
                return True

        # 'suce' in ingredients (OCR of sucre)
        if word_key == "suce":
            if any(s in clean_surrounding for s in ("sirop", "glucose", "eau", "lait", "farine", "tournesol", "blond", "canne", "matiere", "extrait", "paprika", "sel")):
                return True

        # 'mong' in ingredients (OCR of mono- and diglycerides or moong dal)
        if word_key == "mong":
            if any(m in clean_surrounding for m in ("diglyceride", "ester", "tartrique", "dall", "daal", "lentil", "moong")):
                return True

        # 'negre' in Catalan, Romanian, or food context (black pepper, black rice, black wine, blackcurrants)
        if word_key == "negre":
            if (lang or "").lower() in ("ca", "ro", "cat", "catalan", "romanian"):
                return True
            if any(n in clean_surrounding for n in ("vi", "pebre", "arros", "arròs", "coacaze", "coacăze", "xocolata", "te", "fasole", "paine", "pomme", "jus", "lactics", "oliva")):
                return True

        # 'fag' in Romanian (lemn de fag = beech wood) or Italian (fag. = fagioli)
        if word_key == "fag":
            if (lang or "").lower() in ("ro", "rum", "ron", "romanian", "it", "ita", "italian"):
                return True
            if any(f in clean_surrounding for f in ("lemn", "afumat", "fum", "bianchi", "spagna", "fagioli")):
                return True

        # 'trique' in French (OCR of acide citrique)
        if word_key == "trique":
            if any(t in clean_surrounding for t in ("acide", "acidifiant", "correcteur", "acidite", "citrique", "alginate")):
                return True

        # 'cul' in Italian (OCR of 'di cui' in nutrition) or French (culture bactérienne, sel de cuisine)
        if word_key == "cul":
            if any(c in clean_surrounding for c in ("grassi", "acidi", "carboidrati", "zuccheri", "proteine", "sale", "culture", "bacterienne", "bactérienne", "sel", "cuisine")):
                return True

        # 'suck' in ingredients (OCR of sucre / sugar)
        if word_key == "suck":
            if any(s in clean_surrounding for s in ("farine", "ble", "blé", "sauce", "sugar", "wheat", "coffee", "sel", "salt", "teriyaki", "huile", "vegetale", "sirop", "puree", "chocolat")):
                return True

        # 'dick' in German (dick = thick) or brand
        if word_key == "dick":
            if (lang or "").lower() in ("de", "ger", "german") or "germany" in (countries or "").lower():
                return True
            if any(d in clean_surrounding for d in ("extra", "cremig", "saft", "scheiben", "burger", "agaven", "schmelzkase", "puree", "pomme", "carotte", "potiron", "jane")):
                return True

        # 'conne' in ingredients (OCR of 'sucre de canne')
        if word_key == "conne":
            if any(s in clean_surrounding for s in ("sucre", "sirop", "canne", "manioc", "riz", "glucose", "chocolat", "confiture", "entier", "fleur")):
                return True

        # 'bite' in English (bite size, raw bite, sweet bite) or French OCR (farine de blé)
        if word_key == "bite":
            if any(b in clean_surrounding for b in ("size", "two", "raw", "natural", "fruit", "nut", "snack", "energy", "protein", "organic", "farine", "complete", "ble", "sweet", "big", "pro", "poivrons", "peppers", "chilli", "bar")):
                return True

        # 'tit' in ingredients (titanium dioxide) or French
        if word_key == "tit":
            if any(t in clean_surrounding for t in ("color", "colors", "pigment", "red", "blue", "yellow", "dioxide", "dioxyde", "gelatin", "bulles", "ricotta", "gerble")):
                return True

        return False

    def find_violations(
        self,
        text: str,
        lang: Optional[str],
        countries: Optional[str] = None,
        code: Optional[str] = None
    ) -> List[Tuple[str, str, Tuple[int, int]]]:
        """
        Check text for forbidden words.
        Returns a list of (canonical_word, matched_raw_text, (start, end)).
        """
        if not text or not isinstance(text, str):
            return []

        # If product barcode is allowed, return clean
        if code and code in self.allowed_barcodes:
            return []

        pattern = self.get_pattern(lang)
        violations = []

        for m in pattern.finditer(text):
            matched_raw = m.group(0)
            key = canonical_key(matched_raw)

            start, end = m.span()
            if self.is_false_positive(key, matched_raw, text, start, end, lang=lang, countries=countries, code=code):
                continue

            violations.append((key, matched_raw, (start, end)))

        return violations


def make_snippet(text: str, start: int, end: int, context_chars: int = 35) -> str:
    """Extract a clean single-line snippet with [matched_word] highlighted."""
    snip_start = max(0, start - context_chars)
    snip_end = min(len(text), end + context_chars)

    prefix = "..." if snip_start > 0 else ""
    suffix = "..." if snip_end < len(text) else ""

    before = text[snip_start:start]
    match = text[start:end]
    after = text[end:snip_end]

    snippet = f"{prefix}{before}[{match}]{after}{suffix}"
    return re.sub(r"\s+", " ", snippet).strip()


def is_candidate_column(col: str) -> bool:
    """Check if column is one of the target fields for scanning."""
    col_lower = col.lower()
    if col_lower in (
        "code", "url", "link", "lang", "lc", "product_name", "generic_name",
        "abbreviated_product_name", "ingredients_text",
        "packaging_text", "brands", "countries_tags", "countries", "categories_tags",
        "unknown_ingredients_n", "known_ingredients_n", "ingredients_n"
    ):
        return True
    if col_lower.startswith((
        "product_name", "generic_name", "abbreviated_product_name",
        "ingredients_text", "packaging_text", "brands"
    )):
        return True
    return False


def get_field_lang(field_name: str, product_lang: Optional[str]) -> Optional[str]:
    """Derive language code from column suffix (e.g. product_name_fr -> fr) or product lang."""
    m = re.search(r"_([a-z]{2,3})$", field_name.lower())
    if m:
        return m.group(1)
    return product_lang


def iter_csv_records(filepath: str, delimiter: Optional[str] = None, limit: Optional[int] = None) -> Generator[Dict[str, str], None, None]:
    """Stream records from CSV / TSV / GZ file or stdin."""
    is_stdin = (filepath == "-")
    is_gz = filepath.endswith(".gz")

    if is_stdin:
        f = sys.stdin
    elif is_gz:
        f = gzip.open(filepath, "rt", encoding="utf-8", errors="replace")
    else:
        f = open(filepath, "r", encoding="utf-8", errors="replace")

    try:
        if not delimiter:
            if is_stdin:
                first_line = f.readline()
                delimiter = "\t" if "\t" in first_line else ","
                from itertools import chain
                reader_f = chain([first_line], f)
                reader = csv.DictReader(reader_f, delimiter=delimiter)
                count = 0
                for row in reader:
                    yield row
                    count += 1
                    if limit and count >= limit:
                        return
                return
            else:
                first_line = f.readline()
                delimiter = "\t" if "\t" in first_line else ","
                f.seek(0)

        reader = csv.DictReader(f, delimiter=delimiter)
        count = 0
        for row in reader:
            yield row
            count += 1
            if limit and count >= limit:
                return
    finally:
        if not is_stdin:
            f.close()


def iter_parquet_records(filepath: str, batch_size: int = 10000, limit: Optional[int] = None) -> Generator[Dict[str, str], None, None]:
    """Stream records from Parquet using pyarrow, duckdb, or pandas."""
    # 1. Try PyArrow (fastest, standard streaming)
    try:
        import pyarrow.parquet as pq
        parquet_file = pq.ParquetFile(filepath)
        top_fields = parquet_file.schema_arrow.names if hasattr(parquet_file, "schema_arrow") else parquet_file.schema.names
        cols_to_read = [c for c in top_fields if is_candidate_column(c)]
        if "code" in top_fields and "code" not in cols_to_read:
            cols_to_read.append("code")

        count = 0
        for batch in parquet_file.iter_batches(batch_size=batch_size, columns=cols_to_read):
            pydict = batch.to_pydict()
            num_rows = len(batch)
            for i in range(num_rows):
                row = {}
                row_lang = None
                if "lang" in pydict and pydict["lang"][i]:
                    row_lang = str(pydict["lang"][i]).strip().lower()
                elif "lc" in pydict and pydict["lc"][i]:
                    row_lang = str(pydict["lc"][i]).strip().lower()

                u_ing = pydict["unknown_ingredients_n"][i] if "unknown_ingredients_n" in pydict else None
                k_ing = pydict["known_ingredients_n"][i] if "known_ingredients_n" in pydict else None
                n_ing = pydict["ingredients_n"][i] if "ingredients_n" in pydict else None

                all_ingredients_recognized = (
                    u_ing == 0 and (
                        (k_ing is not None and k_ing > 0) or
                        (n_ing is not None and n_ing > 0)
                    )
                )

                primary_name = ""

                for c in cols_to_read:
                    val = pydict[c][i]
                    if val is None:
                        continue
                    if isinstance(val, list):
                        if val and isinstance(val[0], dict) and "text" in val[0]:
                            # Group texts by language (only one text per language for the product)
                            texts_by_lang: Dict[str, str] = {}
                            for item in val:
                                if not isinstance(item, dict):
                                    continue
                                t = str(item.get("text") or "").strip()
                                if not t:
                                    continue
                                l = str(item.get("lang") or "unknown").strip().lower()
                                if l == "main":
                                    l = row_lang or "main"
                                if l not in texts_by_lang or len(t) > len(texts_by_lang[l]):
                                    texts_by_lang[l] = t

                            # If all ingredients are recognized, check if we can skip ingredients
                            if c.startswith("ingredients") and all_ingredients_recognized:
                                distinct_langs = {l for l in texts_by_lang if l not in ("unknown",)}
                                if len(distinct_langs) <= 1:
                                    # All ingredients recognized and no other languages: skip scanning ingredients
                                    continue
                                else:
                                    # Other languages exist: skip recognized primary language, keep others
                                    if row_lang and row_lang in texts_by_lang:
                                        del texts_by_lang[row_lang]

                            for l, text in texts_by_lang.items():
                                row[f"{c}_{l}"] = text
                                if c.startswith("product_name") and (not primary_name or l in ("main", "en", row_lang)):
                                    primary_name = text
                        else:
                            row[c] = ",".join(str(x) for x in val if x is not None)
                    else:
                        row[c] = val

                if primary_name and "product_name" not in row:
                    row["_product_name_display"] = primary_name

                # Check if URL/link has a product slug to inspect
                url_str = str(row.get("link") or row.get("url") or "")
                if "/product/" in url_str:
                    parts = url_str.split("/product/")[-1].split("/")
                    if len(parts) > 1 and parts[1]:
                        slug = parts[1].replace("-", " ").replace("_", " ").strip()
                        if slug:
                            row["url_slug"] = slug

                yield row
                count += 1
                if limit and count >= limit:
                    return
        return
    except ImportError:
        pass

    # 2. Try DuckDB
    try:
        import duckdb
        con = duckdb.connect()
        desc = con.execute(f"DESCRIBE SELECT * FROM read_parquet('{filepath}')").fetchall()
        all_cols = [r[0] for r in desc]
        cols_to_read = [c for c in all_cols if is_candidate_column(c)]
        cols_sql = ", ".join(f'"{c}"' for c in cols_to_read)

        cursor = con.cursor()
        cursor.execute(f"SELECT {cols_sql} FROM read_parquet('{filepath}')")
        count = 0
        while True:
            chunk = cursor.fetchmany(batch_size)
            if not chunk:
                break
            for rec in chunk:
                row = dict(zip(cols_to_read, rec))
                yield row
                count += 1
                if limit and count >= limit:
                    return
        return
    except ImportError:
        pass

    # 3. Try Pandas
    try:
        import pandas as pd
        df = pd.read_parquet(filepath)
        cols_to_read = [c for c in df.columns if is_candidate_column(c)]
        count = 0
        for _, rec in df[cols_to_read].iterrows():
            yield rec.to_dict()
            count += 1
            if limit and count >= limit:
                return
        return
    except ImportError:
        pass

    raise RuntimeError(
        "\n[!] Parquet reading requires 'pyarrow' or 'duckdb'.\n"
        "Please install pyarrow using:\n"
        "    pip install pyarrow\n"
        "or duckdb using:\n"
        "    pip install duckdb\n\n"
        "Alternatively, scan an Open Food Facts CSV or TSV export directly with zero external dependencies:\n"
        "    python3 scripts/detect_forbidden_words.py --input en.openfoodfacts.org.products.csv.gz\n"
    )


def detect_file_format(filepath: str) -> str:
    """Detect whether file is parquet or csv."""
    if filepath == "-":
        return "csv"
    low = filepath.lower()
    if low.endswith(".parquet") or ".parquet?" in low:
        return "parquet"
    return "csv"


def build_product_url(code: str, url: Optional[str]) -> str:
    """Return product page URL."""
    if url and str(url).strip() and str(url).startswith("http"):
        return str(url).strip()
    clean_code = str(code).strip()
    return f"https://world.openfoodfacts.org/product/{clean_code}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Detect forbidden words and vandalism in Open Food Facts data exports (Parquet or CSV/TSV).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        "-i", "--input", required=True,
        help="Path to input export file (.parquet, .csv, .tsv, .csv.gz, .tsv.gz, or '-' for stdin)."
    )
    parser.add_argument(
        "-o", "--output", default="forbidden_words_issues.csv",
        help="Path to output CSV report (default: forbidden_words_issues.csv)."
    )
    parser.add_argument(
        "-w", "--words-file", default=None,
        help="Optional path to custom forbidden words file (default: conf/forbidden_words.txt)."
    )
    parser.add_argument(
        "-a", "--allowlist", default=None,
        help="Path to configurable allow list file (default: conf/forbidden_words_allowlist.txt)."
    )
    parser.add_argument(
        "-b", "--batch-size", type=int, default=10000,
        help="Batch size for reading Parquet and progress reporting (default: 10000)."
    )
    parser.add_argument(
        "-n", "--limit", type=int, default=None,
        help="Maximum number of products to scan (useful for quick dry runs)."
    )
    parser.add_argument(
        "--max-issues", type=int, default=None,
        help="Stop scanning after finding this number of issues."
    )
    parser.add_argument(
        "--all-languages", action="store_true",
        help="Scan all languages against every product, ignoring product language code."
    )
    parser.add_argument(
        "--one-row-per-product", action="store_true",
        help="Output one row per product barcode instead of one row per violation."
    )
    parser.add_argument(
        "-q", "--quiet", action="store_true",
        help="Suppress progress updates on stderr."
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="Print each violation to stderr as it is found."
    )

    args = parser.parse_args()

    # Handle remote HTTP/HTTPS URLs
    input_path = args.input
    if input_path.startswith(("http://", "https://")):
        parsed_name = input_path.split("?")[0].rstrip("/").split("/")[-1] or "export.data"
        local_target = os.path.join(".", parsed_name)
        if os.path.exists(local_target):
            if not args.quiet:
                sys.stderr.write(f"Using already downloaded local file: {local_target}\n")
            input_path = local_target
        else:
            if not args.quiet:
                sys.stderr.write(f"Downloading remote file: {args.input}\nSaving to: {local_target}\n")
            try:
                import urllib.request
                def progress(blocknum, blocksize, totalsize):
                    read = blocknum * blocksize
                    if totalsize > 0 and not args.quiet:
                        pct = min(100.0, read * 100.0 / totalsize)
                        sys.stderr.write(f"\rDownloading: {read / (1024*1024):.1f} MB / {totalsize / (1024*1024):.1f} MB ({pct:.1f}%)")
                        sys.stderr.flush()
                urllib.request.urlretrieve(args.input, local_target, reporthook=progress)
                if not args.quiet:
                    sys.stderr.write("\nDownload complete.\n")
                input_path = local_target
            except Exception as e:
                sys.stderr.write(f"\nError downloading {args.input}: {e}\n")
                return 1

    # Verify input exists (unless stdin)
    if input_path != "-" and not os.path.exists(input_path):
        sys.stderr.write(f"Error: input file '{input_path}' not found.\n")
        return 1

    # Load forbidden words and allow list
    words_by_lang = load_forbidden_words(args.words_file)
    allowed_barcodes, allowed_patterns, country_rules = load_allowlist(args.allowlist)

    detector = ForbiddenWordsDetector(
        words_by_lang=words_by_lang,
        allowed_barcodes=allowed_barcodes,
        allowed_patterns=allowed_patterns,
        country_rules=country_rules,
        all_languages=args.all_languages
    )

    total_words = sum(len(w) for w in words_by_lang.values())
    langs_list = ", ".join(f"{k} ({len(v)})" for k, v in sorted(words_by_lang.items()))
    if not args.quiet:
        sys.stderr.write(f"Loaded {total_words} forbidden words across languages: {langs_list}\n")
        sys.stderr.write(f"Loaded allowlist: {len(allowed_barcodes)} barcodes, {len(allowed_patterns)} patterns.\n")
        sys.stderr.write(f"Scanning '{input_path}' -> writing results to '{args.output}'\n")

    # Select reader
    fmt = detect_file_format(input_path)
    if fmt == "parquet":
        record_stream = iter_parquet_records(input_path, batch_size=args.batch_size, limit=args.limit)
    else:
        record_stream = iter_csv_records(input_path, limit=args.limit)

    # Output CSV columns
    out_headers = [
        "code", "url", "product_name", "lang",
        "field_matched", "forbidden_word_matched",
        "matched_text_snippet", "countries_tags"
    ]

    out_file = open(args.output, "w", encoding="utf-8", newline="")
    writer = csv.DictWriter(out_file, fieldnames=out_headers)
    writer.writeheader()
    out_file.flush()

    products_scanned = 0
    issues_found = 0
    bypassed_barcodes = 0
    affected_barcodes: Set[str] = set()
    field_counts: Dict[str, int] = {}
    word_counts: Dict[str, int] = {}
    lang_counts: Dict[str, int] = {}

    start_time = time.time()
    last_report_time = start_time

    try:
        for row in record_stream:
            products_scanned += 1
            code = str(row.get("code") or "").strip()
            if not code:
                continue

            # Check barcode allowlist directly
            if code in allowed_barcodes:
                bypassed_barcodes += 1
                continue

            url = build_product_url(code, row.get("url"))
            product_lang = str(row.get("lang") or row.get("lc") or "").strip().lower() or None
            product_name = str(row.get("product_name") or row.get("_product_name_display") or row.get("product_name_en") or row.get("product_name_fr") or "").strip()
            countries = str(row.get("countries_tags") or row.get("countries") or "").strip()

            # Check if all ingredients are recognized by taxonomy parser (to skip ingredients when no other languages)
            u_ing = row.get("unknown_ingredients_n")
            k_ing = row.get("known_ingredients_n")
            n_ing = row.get("ingredients_n")
            all_ing_rec = False
            try:
                if u_ing is not None and str(u_ing).isdigit() and int(u_ing) == 0:
                    k_int = int(k_ing) if k_ing is not None and str(k_ing).isdigit() else 0
                    n_int = int(n_ing) if n_ing is not None and str(n_ing).isdigit() else 0
                    if k_int > 0 or n_int > 0:
                        all_ing_rec = True
            except Exception:
                all_ing_rec = False

            product_issues = []
            seen_texts: Set[Tuple[str, Optional[str]]] = set()

            for field, val in row.items():
                if val is None or field.startswith("_"):
                    continue
                val_str = str(val).strip()
                if not val_str:
                    continue

                field_lower = field.lower()
                is_name = field_lower.startswith(("product_name", "generic_name", "abbreviated_product_name", "url_slug"))
                is_ing = field_lower.startswith(("ingredients_text", "packaging_text"))
                is_brand = (field_lower == "brands" or (field_lower.startswith("brands_") and not field_lower.endswith("_tags")))

                if not (is_name or is_ing or is_brand):
                    continue

                field_lang = get_field_lang(field, product_lang)

                # Skip ingredients if all ingredients are recognized and no other languages
                if is_ing and all_ing_rec:
                    if field_lang in (None, product_lang, "main", "en"):
                        continue

                # Ensure only one scan per unique (text, lang) per product
                text_key = (val_str, field_lang)
                if text_key in seen_texts:
                    continue
                seen_texts.add(text_key)

                violations = detector.find_violations(val_str, field_lang, countries=countries, code=code)

                for canon_word, matched_raw, (s_idx, e_idx) in violations:
                    snippet = make_snippet(val_str, s_idx, e_idx)
                    product_issues.append({
                        "field": field,
                        "word": canon_word,
                        "raw": matched_raw,
                        "snippet": snippet,
                        "lang": field_lang or "unknown"
                    })

            if product_issues:
                affected_barcodes.add(code)

                if args.one_row_per_product:
                    fields_str = "; ".join(sorted(set(i["field"] for i in product_issues)))
                    words_str = "; ".join(sorted(set(i["word"] for i in product_issues)))
                    snippets_str = " | ".join(i["snippet"] for i in product_issues[:3])
                    writer.writerow({
                        "code": code,
                        "url": url,
                        "product_name": product_name,
                        "lang": product_lang or "unknown",
                        "field_matched": fields_str,
                        "forbidden_word_matched": words_str,
                        "matched_text_snippet": snippets_str,
                        "countries_tags": countries,
                    })
                    issues_found += len(product_issues)
                else:
                    for issue in product_issues:
                        issues_found += 1
                        field_counts[issue["field"]] = field_counts.get(issue["field"], 0) + 1
                        word_counts[issue["word"]] = word_counts.get(issue["word"], 0) + 1
                        lang_counts[issue["lang"]] = lang_counts.get(issue["lang"], 0) + 1

                        writer.writerow({
                            "code": code,
                            "url": url,
                            "product_name": product_name,
                            "lang": issue["lang"],
                            "field_matched": issue["field"],
                            "forbidden_word_matched": issue["word"],
                            "matched_text_snippet": issue["snippet"],
                            "countries_tags": countries,
                        })

                        if args.verbose:
                            sys.stderr.write(f"[{code}] {issue['field']}: {issue['word']} -> {issue['snippet']}\n")

                out_file.flush()

                if args.max_issues and issues_found >= args.max_issues:
                    if not args.quiet:
                        sys.stderr.write(f"\nReached maximum issues limit ({args.max_issues}). Stopping.\n")
                    break

            now = time.time()
            if not args.quiet and (products_scanned % 10000 == 0 or (now - last_report_time) >= 5.0):
                elapsed = now - start_time
                speed = products_scanned / elapsed if elapsed > 0 else 0
                pct = (len(affected_barcodes) / products_scanned * 100) if products_scanned > 0 else 0
                sys.stderr.write(
                    f"\rScanned: {products_scanned:,} products | Issues: {issues_found:,} ({pct:.3f}%) | "
                    f"Allowlisted: {bypassed_barcodes:,} | Speed: {speed:,.0f} prod/s | Elapsed: {elapsed:.1f}s"
                )
                sys.stderr.flush()
                last_report_time = now

    finally:
        out_file.close()

    total_elapsed = time.time() - start_time
    speed = products_scanned / total_elapsed if total_elapsed > 0 else 0

    if not args.quiet:
        sys.stderr.write("\n\n" + "=" * 60 + "\n")
        sys.stderr.write("FORBIDDEN WORDS SCAN COMPLETED\n")
        sys.stderr.write("=" * 60 + "\n")
        sys.stderr.write(f"Total products scanned:   {products_scanned:,}\n")
        sys.stderr.write(f"Total violations found:   {issues_found:,}\n")
        sys.stderr.write(f"Total affected products:  {len(affected_barcodes):,}\n")
        sys.stderr.write(f"Allowlisted barcodes:     {bypassed_barcodes:,}\n")
        sys.stderr.write(f"Total scanning time:      {total_elapsed:.2f} seconds ({speed:,.0f} prod/s)\n")
        sys.stderr.write(f"Report saved to:          {args.output}\n\n")

        if field_counts:
            sys.stderr.write("Top affected fields:\n")
            for f_name, c in sorted(field_counts.items(), key=lambda x: x[1], reverse=True)[:5]:
                sys.stderr.write(f"  - {f_name}: {c}\n")
            sys.stderr.write("\n")

        if word_counts:
            sys.stderr.write("Top detected forbidden words:\n")
            for w_name, c in sorted(word_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
                sys.stderr.write(f"  - {w_name}: {c}\n")
            sys.stderr.write("\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
