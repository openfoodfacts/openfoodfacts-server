#!/usr/bin/env python3
"""
check_wikidata_mappings.py - Validate new or modified Wikidata mappings in taxonomies.

This script identifies newly added or modified `wikidata:*` lines in taxonomy files
(by comparing against a git base ref, e.g. origin/main) and queries the Wikidata API
to verify that:
1. The Wikidata entity actually exists.
2. The entity is not a completely mismatched type (e.g. star, celestial body, human,
   musical album, film, railway station, scholarly article).
3. The entity name matches the taxonomy entry name or one of its synonyms/translations
   (accounting for case, accents, punctuation, corporate suffixes, and token overlap).
4. The entity class (instance of P31 / subclass of P279) is compatible with the taxonomy
   domain (e.g. brands should be brands/companies, food categories should be foods/dishes,
   ingredients should be ingredients/plants/compounds, etc.).

Only NEW or MODIFIED entries are queried to strictly avoid overloading Wikidata servers.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from typing import Dict, List, Optional, Set, Tuple

WIKIDATA_API_URL = "https://www.wikidata.org/w/api.php"
USER_AGENT = "OpenFoodFacts-CI/1.0 (https://openfoodfacts.org; contact@openfoodfacts.org)"

# Common disallowed entity classes across food/product taxonomies
DISALLOWED_CLASS_QIDS = {
    # Astronomical objects
    "Q6999",     # astronomical object
    "Q13890",    # star / double star
    "Q2247863",  # giant star
    "Q67206691", # infrared source (astronomical)
    "Q89211",    # constellation
    "Q318",      # galaxy
    "Q634",      # planet
    "Q48",       # open cluster
    "Q523",      # star cluster
    "Q223",      # solar system body
    "Q10887",    # supernova
    # Humans / people
    "Q5",        # human
    "Q215627",   # person
    # Creative works & media
    "Q11424",    # film
    "Q482994",   # album
    "Q7366",     # song
    "Q7725634",  # literary work
    "Q5398426",  # television series
    "Q7889",     # video game
    "Q24856",    # film series
    "Q17537576", # creative work
    # Academic & publications
    "Q13442814", # scholarly article
    "Q732577",   # publication
    "Q5633421",  # scientific journal
    # Transport infrastructure
    "Q55488",    # railway station
    "Q1248784",  # airport
}

DISALLOWED_CLASS_KEYWORDS = [
    "star", "constellation", "galaxy", "planet", "astronomical object",
    "human", "homo sapiens",
    "film", "album", "song", "musical track", "television series",
    "video game", "scholarly article", "academic journal",
    "railway station", "airport",
]

# Taxonomy-specific expected keywords in P31/P279 class labels and descriptions
EXPECTED_CLASS_KEYWORDS_BY_TYPE = {
    "brand": [
        "brand", "trademark", "company", "enterprise", "business", "corporation",
        "manufacturer", "brewery", "winery", "distillery", "retailer", "supermarket",
        "food brand", "food manufacturer", "chain", "cooperative", "conglomerate",
        "holding", "producer", "firm", "label",
    ],
    "category": [
        "food", "dish", "beverage", "drink", "condiment", "snack", "baked good",
        "dairy product", "cheese", "bread", "meat", "fruit", "vegetable", "cereal",
        "crop", "wine", "beer", "product", "cosmetic", "hygiene", "pet food",
        "consumer product", "consumer good", "taxon", "plant", "fermented",
        "appellation", "cru", "sauce", "confectionery", "dessert",
    ],
    "ingredient": [
        "ingredient", "food", "substance", "chemical compound", "chemical substance",
        "plant", "taxon", "spice", "herb", "mineral", "nutrient", "dairy",
        "oil", "fat", "animal product", "vegetable", "fruit", "seed", "extract",
        "mixture", "flour", "flavor", "flavour",
    ],
    "additive": [
        "additive", "food additive", "chemical compound", "chemical substance",
        "dye", "food coloring", "food colouring", "preservative", "flavor",
        "flavour", "flavoring", "enzyme", "antioxidant", "emulsifier",
        "thickening agent", "sweetener", "acidity regulator",
    ],
    "label": [
        "certification", "label", "trademark", "standard", "ecolabel",
        "organic certification", "quality mark", "hallmark", "award",
        "organization", "seal", "conformity mark",
    ],
    "country": [
        "country", "sovereign state", "island nation", "dependent territory",
        "state", "federation",
    ],
    "origin": [
        "country", "sovereign state", "island nation", "region", "province",
        "state", "administrative territorial entity", "geographic region",
        "geographical feature", "mountain", "river", "valley", "lake", "territory",
    ],
    "packaging_material": [
        "packaging material", "material", "plastic", "metal", "glass",
        "paper", "cardboard", "wood", "textile", "polymer", "aluminium", "aluminum",
    ],
    "packaging_shape": [
        "container", "packaging", "bottle", "can", "box", "bag", "jar",
        "wrapper", "carton", "tube", "pouch", "packet", "pot", "tray",
    ],
    "nutrient": [
        "nutrient", "vitamin", "mineral", "amino acid", "nucleotide",
        "chemical compound", "fatty acid", "carbohydrate", "protein",
    ],
    "allergen": [
        "allergen", "food", "plant", "animal", "chemical compound", "substance",
    ],
}

# Words to ignore when stripping corporate suffixes or calculating token overlap
CORPORATE_SUFFIXES = {
    "co", "company", "corp", "corporation", "inc", "incorporated", "ltd", "limited",
    "llc", "gmbh", "sa", "sas", "spa", "s p a", "plc", "group", "groupe", "holdings",
    "holding", "brand", "brands", "products", "food", "foods", "the", "cie", "nv",
    "bv", "ag", "kgaa", "se", "srl", "sl", "bhd", "pvt", "pty",
}

STOPWORDS = {
    "the", "a", "an", "and", "or", "of", "in", "for", "with", "at", "by", "from",
    "de", "la", "le", "les", "du", "des", "en", "et", "ou", "pour", "avec", "par",
    "der", "die", "das", "und", "oder", "von", "mit", "fur",
}


def normalize_string(s: str) -> str:
    """Normalize string: remove accents, lowercase, contract dotted abbreviations, simplify punctuation."""
    if not s:
        return ""
    # Unicode NFKD decomposition
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    # Contract dotted abbreviations: s.a. -> sa, s.p.a. -> spa, c.o. -> co
    s = re.sub(r"\b([a-z])\.(?=[a-z]\b|\.)", r"\1", s)
    # Replace & with and
    s = s.replace("&", " and ")
    # Replace non-alphanumeric with spaces
    s = re.sub(r"[^\w\s]", " ", s)
    return " ".join(s.split())


def strip_corporate_suffixes(s: str) -> str:
    """Strip legal corporate suffixes from brand/company names."""
    # Also handle multi-word combinations like 's a', 's p a'
    s = re.sub(r"\b(s\s+a|s\s+p\s+a|co\s+ltd)\b", " ", s)
    tokens = [w for w in s.split() if w not in CORPORATE_SUFFIXES]
    return " ".join(tokens)


def get_tokens(s: str) -> Set[str]:
    """Get meaningful tokens from normalized string."""
    tokens = set(s.split())
    meaningful = tokens - STOPWORDS - CORPORATE_SUFFIXES
    return meaningful if meaningful else tokens


def determine_taxonomy_type(file_path: str) -> str:
    """Infer taxonomy domain from file path."""
    basename = os.path.basename(file_path).lower()
    if "brand" in basename:
        return "brand"
    if "category" in basename or "categories" in basename:
        return "category"
    if "ingredient" in basename:
        return "ingredient"
    if "additive" in basename:
        return "additive"
    if "label" in basename:
        return "label"
    if "country" in basename or "countries" in basename:
        return "country"
    if "origin" in basename:
        return "origin"
    if "packaging_material" in basename:
        return "packaging_material"
    if "packaging_shape" in basename:
        return "packaging_shape"
    if any(k in basename for k in ["nutrient", "mineral", "vitamin", "amino_acid", "nucleotide"]):
        return "nutrient"
    if "allergen" in basename:
        return "allergen"
    return "other"


def parse_taxonomy_entries(file_path: str, content: Optional[str] = None) -> List[Dict]:
    """
    Parse a taxonomy file into discrete entry blocks with line numbers and parsed fields.
    Each block is separated by blank line(s).
    """
    if content is None:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading {file_path}: {e}", file=sys.stderr)
            return []

    lines = content.splitlines()
    entries = []
    current_lines = []
    block_start_line = 1

    for line_idx, line in enumerate(lines, start=1):
        if not line.strip():
            if current_lines:
                entry = _build_entry(file_path, block_start_line, line_idx - 1, current_lines)
                if entry:
                    entries.append(entry)
                current_lines = []
            block_start_line = line_idx + 1
        else:
            if not current_lines:
                block_start_line = line_idx
            current_lines.append((line_idx, line))

    if current_lines:
        entry = _build_entry(file_path, block_start_line, len(lines), current_lines)
        if entry:
            entries.append(entry)

    return entries


def _build_entry(file_path: str, start_line: int, end_line: int, lines_with_nums: List[Tuple[int, str]]) -> Optional[Dict]:
    """Build a structured entry dict from lines."""
    names = []
    parents = []
    properties = {}
    wikidata_qids = []
    canonical_name = None

    for line_no, raw_line in lines_with_nums:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("<"):
            parent = line[1:].strip()
            parents.append(parent)
            continue

        # Property lines like wikidata:en: Q12345
        prop_match = re.match(r"^([\w-]+):\s*([a-zA-Z]{2,3}(?:[-_][a-zA-Z]{2,4})?):\s*(.*)$", line)
        if prop_match:
            prop_name, lang, prop_val = prop_match.group(1), prop_match.group(2), prop_match.group(3).strip()
            prop_key = f"{prop_name}:{lang}"
            properties[prop_key] = prop_val
            if prop_name.lower() == "wikidata":
                qid_match = re.search(r"\b(Q\d+)\b", prop_val, re.IGNORECASE)
                if qid_match:
                    wikidata_qids.append((line_no, qid_match.group(1).upper()))
            continue

        # Simple property like wikidata: Q12345
        simple_prop = re.match(r"^wikidata:\s*([Qq]\d+)", line)
        if simple_prop:
            wikidata_qids.append((line_no, simple_prop.group(1).upper()))
            continue

        # Language entry lines like xx: Nissin, Nissin Foods or en: Instant noodles
        lang_match = re.match(r"^([a-zA-Z]{2,3}(?:[-_][a-zA-Z]{2,4})?):\s*(.*)$", line)
        if lang_match:
            lang, names_str = lang_match.group(1), lang_match.group(2)
            # Remove trailing comments
            names_str = re.sub(r"\s*#.*$", "", names_str).strip()
            if names_str:
                for item in re.split(r"\s*,\s*", names_str):
                    item = item.strip()
                    if item:
                        names.append(item)
                        if canonical_name is None:
                            canonical_name = item

    if not names and not wikidata_qids:
        return None

    return {
        "file_path": file_path,
        "taxonomy_type": determine_taxonomy_type(file_path),
        "start_line": start_line,
        "end_line": end_line,
        "canonical_name": canonical_name or (names[0] if names else "unnamed"),
        "names": names,
        "parents": parents,
        "properties": properties,
        "wikidata_qids": wikidata_qids,
    }


def parse_git_diff_for_new_wikidata(diff_text: str) -> List[Dict]:
    """
    Parse unified git diff output and extract NEW or MODIFIED wikidata entries with:
    - file_path
    - line_number in new file
    - qid
    """
    new_entries = []
    current_file = None
    current_new_line = 0

    for line in diff_text.splitlines():
        if line.startswith("diff --git "):
            current_file = None
        elif line.startswith("+++ b/"):
            current_file = line[6:].strip()
        elif line.startswith("@@ "):
            # Example: @@ -10,6 +12,8 @@
            hunk_match = re.search(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            if hunk_match:
                current_new_line = int(hunk_match.group(1))
        elif line.startswith("+") and not line.startswith("+++"):
            if current_file and "taxonomies/" in current_file and current_file.endswith(".txt"):
                content = line[1:].strip()
                # Check for wikidata mapping
                m = re.search(r"^\s*wikidata(?::[a-zA-Z0-9_-]+)?:\s*([Qq]\d+)\b", content)
                if m:
                    qid = m.group(1).upper()
                    new_entries.append({
                        "file_path": current_file,
                        "line_no": current_new_line,
                        "qid": qid,
                    })
            current_new_line += 1
        elif line.startswith("-") and not line.startswith("---"):
            # Deletions do not advance line number in new file
            pass
        else:
            # Context lines advance line number in new file
            current_new_line += 1

    return new_entries


def fetch_wikidata_entities(qids: Set[str]) -> Tuple[Dict[str, Dict], Dict[str, Dict]]:
    """
    Batch query the Wikidata API for entities and their P31/P279 classes.
    Returns:
    - entities: dict of QID -> entity data
    - classes: dict of class QID -> {label, desc}
    """
    if not qids:
        return {}, {}

    entities = {}
    qid_list = sorted(list(qids))
    batch_size = 50

    # 1. Fetch the requested entities
    for i in range(0, len(qid_list), batch_size):
        batch = qid_list[i : i + batch_size]
        params = {
            "action": "wbgetentities",
            "ids": "|".join(batch),
            "props": "labels|aliases|descriptions|claims|sitelinks",
            "format": "json",
        }
        url = f"{WIKIDATA_API_URL}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for qid, entity_data in data.get("entities", {}).items():
                    entities[qid] = entity_data
        except Exception as e:
            print(f"Error fetching Wikidata batch {batch}: {e}", file=sys.stderr)

    # 2. Extract P31 and P279 class Q-IDs to fetch their labels and descriptions
    class_qids = set()
    for entity in entities.values():
        claims = entity.get("claims", {})
        for prop in ["P31", "P279"]:
            for snak in claims.get(prop, []):
                val = snak.get("mainsnak", {}).get("datavalue", {}).get("value")
                if isinstance(val, dict) and "id" in val:
                    class_qids.add(val["id"])

    # 3. Fetch class entities
    classes = {}
    class_qid_list = sorted(list(class_qids))
    for i in range(0, len(class_qid_list), batch_size):
        batch = class_qid_list[i : i + batch_size]
        params = {
            "action": "wbgetentities",
            "ids": "|".join(batch),
            "props": "labels|descriptions",
            "languages": "en,fr",
            "format": "json",
        }
        url = f"{WIKIDATA_API_URL}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for cid, centity in data.get("entities", {}).items():
                    en_label = centity.get("labels", {}).get("en", {}).get("value") or centity.get("labels", {}).get("fr", {}).get("value") or ""
                    en_desc = centity.get("descriptions", {}).get("en", {}).get("value") or centity.get("descriptions", {}).get("fr", {}).get("value") or ""
                    classes[cid] = {"label": en_label, "desc": en_desc}
        except Exception as e:
            print(f"Error fetching Wikidata class batch {batch}: {e}", file=sys.stderr)

    return entities, classes


def check_name_match(entry_names: List[str], entity: Dict) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Check if any name in entry_names matches any Wikidata label, alias, or Wikipedia title.
    Returns: (matched, matched_entry_name, matched_wikidata_name)
    """
    if not entry_names:
        return False, None, None

    # Collect all Wikidata candidate names
    candidates = []

    # Labels
    for lang, label_info in entity.get("labels", {}).items():
        val = label_info.get("value")
        if val:
            candidates.append(val)

    # Aliases
    for lang, alias_list in entity.get("aliases", {}).items():
        for alias_info in alias_list:
            val = alias_info.get("value")
            if val:
                candidates.append(val)

    # Wikipedia sitelinks
    for site, site_info in entity.get("sitelinks", {}).items():
        title = site_info.get("title")
        if title:
            # Strip trailing disambiguation like " (food)" or " (company)"
            clean_title = re.sub(r"\s*\([^)]*\)$", "", title)
            candidates.append(clean_title)

    # Tier 1: Exact and normalized match
    normalized_candidates = [(c, normalize_string(c)) for c in candidates]

    for name in entry_names:
        norm_name = normalize_string(name)
        if not norm_name:
            continue

        no_space_name = norm_name.replace(" ", "")

        for orig_c, norm_c in normalized_candidates:
            if not norm_c:
                continue

            # Exact normalized match
            if norm_name == norm_c:
                return True, name, orig_c

            # No-space match (e.g. "Instant-Nudeln" vs "Instantnudeln", "Coca-Cola" vs "CocaCola")
            if no_space_name == norm_c.replace(" ", ""):
                return True, name, orig_c

            # Corporate suffix stripping (e.g. "Nissin Food Products" vs "Nissin Foods")
            stripped_name = strip_corporate_suffixes(norm_name)
            stripped_c = strip_corporate_suffixes(norm_c)
            if stripped_name and stripped_c and stripped_name == stripped_c:
                return True, name, orig_c

    # Tier 2: Token subset / containment match for multi-word or compound names
    for name in entry_names:
        norm_name = normalize_string(name)
        tokens_name = get_tokens(norm_name)
        if len(tokens_name) == 0:
            continue

        for orig_c, norm_c in normalized_candidates:
            tokens_c = get_tokens(norm_c)
            if len(tokens_c) == 0:
                continue

            # If tokens of one are completely contained in the other
            # Require at least one multi-character meaningful token match
            if tokens_name.issubset(tokens_c) or tokens_c.issubset(tokens_name):
                # Guard against single-token false positives with very short generic words
                common = tokens_name & tokens_c
                if any(len(t) >= 4 for t in common) or len(common) >= 2:
                    return True, name, orig_c

    return False, None, None


def check_entity_classes(taxonomy_type: str, entity: Dict, class_info: Dict[str, Dict]) -> Dict:
    """
    Check if entity classes (P31 / P279) are allowed or disallowed.
    Returns:
    {
        "is_disallowed": bool,
        "disallowed_reason": Optional[str],
        "is_expected": bool,
        "matched_class": Optional[str],
        "p31_labels": List[str],
    }
    """
    claims = entity.get("claims", {})
    p31_qids = []
    for snak in claims.get("P31", []):
        val = snak.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(val, dict) and "id" in val:
            p31_qids.append(val["id"])

    p279_qids = []
    for snak in claims.get("P279", []):
        val = snak.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(val, dict) and "id" in val:
            p279_qids.append(val["id"])

    all_class_qids = p31_qids + p279_qids
    p31_labels = []

    # 1. Check for explicitly disallowed Q-IDs
    for qid in all_class_qids:
        info = class_info.get(qid, {})
        label = info.get("label", "")
        desc = info.get("desc", "")
        label_desc = f"{label} - {desc}".lower() if label or desc else ""
        if label:
            p31_labels.append(f"{label} ({qid})")

        if qid in DISALLOWED_CLASS_QIDS:
            return {
                "is_disallowed": True,
                "disallowed_reason": f"Disallowed class {label or qid} ({desc or 'unspecified'})",
                "is_expected": False,
                "matched_class": label or qid,
                "p31_labels": p31_labels,
            }

        for kw in DISALLOWED_CLASS_KEYWORDS:
            if re.search(r"\b" + re.escape(kw) + r"\b", label_desc):
                return {
                    "is_disallowed": True,
                    "disallowed_reason": f"Disallowed concept '{kw}' in class {label or qid} ({desc or ''})",
                    "is_expected": False,
                    "matched_class": label or qid,
                    "p31_labels": p31_labels,
                }

    # Also check entity's own description for disallowed keywords (e.g. "orange giant star...")
    entity_desc = entity.get("descriptions", {}).get("en", {}).get("value", "") or entity.get("descriptions", {}).get("fr", {}).get("value", "")
    for kw in DISALLOWED_CLASS_KEYWORDS:
        if re.search(r"\b" + re.escape(kw) + r"\b", entity_desc.lower()):
            return {
                "is_disallowed": True,
                "disallowed_reason": f"Disallowed concept '{kw}' in entity description: '{entity_desc}'",
                "is_expected": False,
                "matched_class": kw,
                "p31_labels": p31_labels,
            }

    # 2. Check for expected domain classes
    expected_kws = EXPECTED_CLASS_KEYWORDS_BY_TYPE.get(taxonomy_type, [])
    matched_class = None
    is_expected = False

    for qid in all_class_qids:
        info = class_info.get(qid, {})
        label = info.get("label", "")
        desc = info.get("desc", "")
        label_desc = f"{label} {desc}".lower()

        for kw in expected_kws:
            if re.search(r"\b" + re.escape(kw) + r"\b", label_desc):
                is_expected = True
                matched_class = f"{label} ({qid})" if label else qid
                break
        if is_expected:
            break

    # If entity description itself indicates the expected domain
    if not is_expected and expected_kws:
        for kw in expected_kws:
            if re.search(r"\b" + re.escape(kw) + r"\b", entity_desc.lower()):
                is_expected = True
                matched_class = f"description contains '{kw}'"
                break

    return {
        "is_disallowed": False,
        "disallowed_reason": None,
        "is_expected": is_expected,
        "matched_class": matched_class,
        "p31_labels": p31_labels,
    }


def validate_wikidata_entry(entry: Dict, entity: Optional[Dict], class_info: Dict[str, Dict]) -> Dict:
    """
    Validate a single Wikidata mapping against its taxonomy entry.
    Returns a result dict:
    {
        "status": "PASS" | "ERROR",
        "file": str,
        "line": int,
        "qid": str,
        "entry_name": str,
        "entity_label": str,
        "entity_desc": str,
        "message": str,
    }
    """
    qid = entry["qid"]
    file_path = entry["file_path"]
    line_no = entry["line_no"]
    taxonomy_type = entry.get("taxonomy_type", "other")
    entry_names = entry.get("names", [])
    entry_name = entry.get("canonical_name", "unnamed")

    # 1. Existence check
    if not entity or entity.get("missing") is not None:
        return {
            "status": "ERROR",
            "file": file_path,
            "line": line_no,
            "qid": qid,
            "entry_name": entry_name,
            "entity_label": "Missing",
            "entity_desc": "",
            "message": f"Entity {qid} does not exist in Wikidata.",
        }

    en_label = entity.get("labels", {}).get("en", {}).get("value") or entity.get("labels", {}).get("fr", {}).get("value") or "No label"
    en_desc = entity.get("descriptions", {}).get("en", {}).get("value") or entity.get("descriptions", {}).get("fr", {}).get("value") or "No description"

    # 2. Check classes
    class_eval = check_entity_classes(taxonomy_type, entity, class_info)
    if class_eval["is_disallowed"]:
        return {
            "status": "ERROR",
            "file": file_path,
            "line": line_no,
            "qid": qid,
            "entry_name": entry_name,
            "entity_label": en_label,
            "entity_desc": en_desc,
            "message": f"{class_eval['disallowed_reason']} - not permitted for {taxonomy_type} taxonomy.",
        }

    # 3. Check name match
    name_matched, matched_entry_name, matched_wd_name = check_name_match(entry_names, entity)

    if not name_matched:
        return {
            "status": "ERROR",
            "file": file_path,
            "line": line_no,
            "qid": qid,
            "entry_name": entry_name,
            "entity_label": en_label,
            "entity_desc": en_desc,
            "message": (
                f"Name mismatch: None of entry names {entry_names[:5]} match Wikidata labels/aliases "
                f"('{en_label}': {en_desc})."
            ),
        }

    # All checks passed
    details = f"Matched name '{matched_entry_name}' with Wikidata '{matched_wd_name}'"
    if class_eval["matched_class"]:
        details += f" (class: {class_eval['matched_class']})"

    return {
        "status": "PASS",
        "file": file_path,
        "line": line_no,
        "qid": qid,
        "entry_name": entry_name,
        "entity_label": en_label,
        "entity_desc": en_desc,
        "message": details,
    }


def find_git_base_ref(specified_base: Optional[str] = None) -> str:
    """Find appropriate git base ref to compare against."""
    if specified_base:
        return specified_base

    # Check GitHub Actions environment
    gh_base = os.environ.get("GITHUB_BASE_REF")
    if gh_base:
        # Check if origin/base exists
        ret = subprocess.run(["git", "rev-parse", "--verify", f"origin/{gh_base}"], capture_output=True, text=True)
        if ret.returncode == 0:
            return f"origin/{gh_base}"
        return gh_base

    # Check origin/main
    ret = subprocess.run(["git", "rev-parse", "--verify", "origin/main"], capture_output=True, text=True)
    if ret.returncode == 0:
        return "origin/main"

    # Check main
    ret = subprocess.run(["git", "rev-parse", "--verify", "main"], capture_output=True, text=True)
    if ret.returncode == 0:
        return "main"

    return "HEAD~1"


def get_git_diff(base_ref: str, head_ref: Optional[str] = None) -> str:
    """Run git diff against base_ref for taxonomies directory."""
    cmd = ["git", "diff", "-U3"]
    if head_ref:
        cmd.append(f"{base_ref}...{head_ref}")
    else:
        cmd.append(base_ref)
    cmd.extend(["--", "taxonomies/"])

    ret = subprocess.run(cmd, capture_output=True, text=True)
    if ret.returncode != 0:
        print(f"Warning: git diff returned non-zero code {ret.returncode}: {ret.stderr}", file=sys.stderr)
        return ""
    return ret.stdout


def main():
    parser = argparse.ArgumentParser(description="Check newly added or modified Wikidata entries in taxonomies.")
    parser.add_argument("--base", help="Git base reference (default: auto-detected, e.g. origin/main)")
    parser.add_argument("--head", help="Git head reference (default: working tree / HEAD)")
    parser.add_argument("--file", help="Check a specific taxonomy file directly")
    parser.add_argument("--all", action="store_true", help="When using --file, check all entries in the file")
    parser.add_argument("--dry-run", action="store_true", help="Parse diff and print entries without calling Wikidata API")
    args = parser.parse_args()

    entries_to_check = []

    if args.file:
        parsed_entries = parse_taxonomy_entries(args.file)
        if args.all:
            for entry in parsed_entries:
                for line_no, qid in entry["wikidata_qids"]:
                    entries_to_check.append({
                        "file_path": args.file,
                        "line_no": line_no,
                        "qid": qid,
                        "taxonomy_type": entry["taxonomy_type"],
                        "canonical_name": entry["canonical_name"],
                        "names": entry["names"],
                    })
        else:
            base_ref = find_git_base_ref(args.base)
            diff_text = get_git_diff(base_ref, args.head)
            diff_entries = parse_git_diff_for_new_wikidata(diff_text)
            diff_entries = [e for e in diff_entries if os.path.abspath(e["file_path"]) == os.path.abspath(args.file)]
            for de in diff_entries:
                target_block = None
                for entry in parsed_entries:
                    if entry["start_line"] <= de["line_no"] <= entry["end_line"]:
                        target_block = entry
                        break
                entries_to_check.append({
                    "file_path": de["file_path"],
                    "line_no": de["line_no"],
                    "qid": de["qid"],
                    "taxonomy_type": target_block["taxonomy_type"] if target_block else determine_taxonomy_type(de["file_path"]),
                    "canonical_name": target_block["canonical_name"] if target_block else "unknown",
                    "names": target_block["names"] if target_block else [],
                })
    else:
        base_ref = find_git_base_ref(args.base)
        print(f"Comparing against git base: {base_ref}")
        diff_text = get_git_diff(base_ref, args.head)
        diff_entries = parse_git_diff_for_new_wikidata(diff_text)

        # Cache parsed files
        file_entries_cache = {}
        for de in diff_entries:
            fpath = de["file_path"]
            if fpath not in file_entries_cache:
                file_entries_cache[fpath] = parse_taxonomy_entries(fpath)
            parsed_blocks = file_entries_cache[fpath]

            target_block = None
            for b in parsed_blocks:
                if b["start_line"] <= de["line_no"] <= b["end_line"]:
                    target_block = b
                    break

            entries_to_check.append({
                "file_path": fpath,
                "line_no": de["line_no"],
                "qid": de["qid"],
                "taxonomy_type": target_block["taxonomy_type"] if target_block else determine_taxonomy_type(fpath),
                "canonical_name": target_block["canonical_name"] if target_block else "unknown",
                "names": target_block["names"] if target_block else [],
            })

    if not entries_to_check:
        print("✅ No new or modified Wikidata entries found in taxonomies.")
        sys.exit(0)

    print(f"Found {len(entries_to_check)} new/modified Wikidata entries to verify.")
    for e in entries_to_check:
        print(f"  - {e['file_path']}:{e['line_no']} -> {e['qid']} ({e['canonical_name']})")

    if args.dry_run:
        print("Dry run requested; skipping API calls.")
        sys.exit(0)

    # Batch fetch from Wikidata
    qids = {e["qid"] for e in entries_to_check}
    print(f"Querying Wikidata for {len(qids)} unique entities...")
    entities, class_info = fetch_wikidata_entities(qids)

    # Validate each entry
    results = []
    has_errors = False

    for entry in entries_to_check:
        entity = entities.get(entry["qid"])
        res = validate_wikidata_entry(entry, entity, class_info)
        results.append(res)
        if res["status"] == "ERROR":
            has_errors = True

    # Output results
    print("\n" + "=" * 60)
    print("WIKIDATA VALIDATION RESULTS")
    print("=" * 60)

    for r in results:
        status_symbol = "✅" if r["status"] == "PASS" else "❌"
        print(f"{status_symbol} [{r['file']}:{r['line']}] {r['entry_name']} -> {r['qid']}")
        print(f"   Wikidata: {r['entity_label']} - {r['entity_desc']}")
        print(f"   Result:   {r['message']}\n")

        # GitHub Actions annotation commands
        if r["status"] == "ERROR":
            print(f"::error file={r['file']},line={r['line']}::[Wikidata Check] {r['message']}")

    # GitHub Actions Step Summary (markdown)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        try:
            with open(summary_path, "a", encoding="utf-8") as f:
                f.write("### 🔍 Wikidata Taxonomy Mappings Verification\n\n")
                f.write("| Status | File:Line | Entry Name | Wikidata QID | Wikidata Label & Description | Details |\n")
                f.write("| :---: | :--- | :--- | :--- | :--- | :--- |\n")
                for r in results:
                    icon = "✅ Pass" if r["status"] == "PASS" else "❌ **Fail**"
                    f.write(
                        f"| {icon} | `{r['file']}:{r['line']}` | **{r['entry_name']}** | "
                        f"[{r['qid']}](https://www.wikidata.org/wiki/{r['qid']}) | "
                        f"*{r['entity_label']}*: {r['entity_desc']} | {r['message']} |\n"
                    )
        except Exception as e:
            print(f"Warning: could not write to GITHUB_STEP_SUMMARY: {e}", file=sys.stderr)

    if has_errors:
        print("❌ Wikidata validation failed! Please fix the errors above.")
        sys.exit(1)
    else:
        print("🎉 All new Wikidata mappings verified successfully!")
        sys.exit(0)


if __name__ == "__main__":
    main()
