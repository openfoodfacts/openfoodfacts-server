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
REPO_ROOT = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Repeated string literal constant to satisfy Sonar S1192
CHEMICAL_COMPOUND = "chemical compound"

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
        "ingredient", "food", "substance", CHEMICAL_COMPOUND, "chemical substance",
        "plant", "taxon", "spice", "herb", "mineral", "nutrient", "dairy",
        "oil", "fat", "animal product", "vegetable", "fruit", "seed", "extract",
        "mixture", "flour", "flavor", "flavour",
    ],
    "additive": [
        "additive", "food additive", CHEMICAL_COMPOUND, "chemical substance",
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
        CHEMICAL_COMPOUND, "fatty acid", "carbohydrate", "protein",
    ],
    "allergen": [
        "allergen", "food", "plant", "animal", CHEMICAL_COMPOUND, "substance",
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

LANG_CODE_RE = re.compile(r"^[a-zA-Z]{2,3}(?:[-_][a-zA-Z0-9]{2,4})?$")
IDENTIFIER_RE = re.compile(r"^[\w-]+$")
QID_SEARCH_RE = re.compile(r"\b(Q\d+)\b", re.IGNORECASE)
GIT_REF_PATTERN = re.compile(r"^[a-zA-Z0-9_][a-zA-Z0-9_.\-/@^~]*$")


def validate_git_ref(ref: str) -> str:
    """
    Validate that ref is a safe git revision/branch name to prevent argument injection (CWE-88).
    Rejects flags starting with '-' and invalid characters.
    """
    if not ref or not isinstance(ref, str):
        raise ValueError(f"Invalid git ref: {ref!r}")
    ref_trimmed = ref.strip()
    if ref_trimmed.startswith("-"):
        raise ValueError(f"Git ref cannot start with '-': {ref_trimmed}")
    if not GIT_REF_PATTERN.match(ref_trimmed):
        raise ValueError(f"Git ref contains disallowed characters: {ref_trimmed}")
    return ref_trimmed


def safe_resolve_path(file_path: str, allowed_base_dir: str = REPO_ROOT) -> str:
    """
    Safely resolve a file path and ensure it is strictly confined to allowed_base_dir.
    Prevents path traversal attacks (CWE-22 / CWE-23).
    """
    if not file_path or not isinstance(file_path, str) or file_path.startswith("-"):
        raise ValueError(f"Invalid file path: {file_path!r}")
    resolved_base = os.path.realpath(allowed_base_dir)
    if not os.path.isabs(file_path):
        resolved_path = os.path.realpath(os.path.join(resolved_base, file_path))
    else:
        resolved_path = os.path.realpath(file_path)

    if not (resolved_path == resolved_base or resolved_path.startswith(resolved_base + os.sep)):
        raise ValueError(f"Path traversal detected: {file_path} is outside allowed directory")

    return resolved_path


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


def _read_taxonomy_file(file_path: str) -> Optional[str]:
    """Safely read taxonomy file content within repository bounds."""
    try:
        safe_path = safe_resolve_path(file_path)
        with open(safe_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return None


def _split_into_blocks(lines: List[str]) -> List[Tuple[int, int, List[Tuple[int, str]]]]:
    """Split raw lines into discrete non-empty blocks with (start_line, end_line, lines_with_nums)."""
    blocks = []
    current_lines: List[Tuple[int, str]] = []
    block_start_line = 1

    for line_idx, line in enumerate(lines, start=1):
        if not line.strip():
            if current_lines:
                blocks.append((block_start_line, line_idx - 1, current_lines))
                current_lines = []
            block_start_line = line_idx + 1
        else:
            if not current_lines:
                block_start_line = line_idx
            current_lines.append((line_idx, line))

    if current_lines:
        blocks.append((block_start_line, len(lines), current_lines))

    return blocks


def _parse_wikidata_simple(line: str, line_no: int) -> Optional[Tuple[int, str]]:
    """Check for simple 'wikidata: Q12345' format."""
    if not line.lower().startswith("wikidata:"):
        return None
    val = line.split(":", 1)[1].strip()
    match = re.match(r"^([Qq]\d+)\b", val)
    if match:
        return (line_no, match.group(1).upper())
    return None


def _parse_entry_line(
    line: str,
    line_no: int,
    parents: List[str],
    properties: Dict[str, str],
    wikidata_qids: List[Tuple[int, str]],
    names: List[str],
) -> None:
    """Parse a single line inside a taxonomy entry block."""
    if line.startswith("<"):
        parent = line[1:].strip()
        if parent:
            parents.append(parent)
        return

    simple_wd = _parse_wikidata_simple(line, line_no)
    if simple_wd:
        wikidata_qids.append(simple_wd)
        return

    if ":" not in line:
        return

    parts = line.split(":", 2)
    # Check for property like prop:lang: value
    if len(parts) == 3 and IDENTIFIER_RE.match(parts[0]) and LANG_CODE_RE.match(parts[1]):
        prop_name, lang, prop_val = parts[0], parts[1], parts[2].strip()
        properties[f"{prop_name}:{lang}"] = prop_val
        if prop_name.lower() == "wikidata":
            qid_match = QID_SEARCH_RE.search(prop_val)
            if qid_match:
                wikidata_qids.append((line_no, qid_match.group(1).upper()))
        return

    # Language entry lines like xx: Nissin, Nissin Foods or en: Instant noodles
    first_token = parts[0].strip()
    if LANG_CODE_RE.match(first_token):
        rest = line.split(":", 1)[1]
        names_str = rest.split("#", 1)[0].strip()
        if names_str:
            for item in names_str.split(","):
                clean_item = item.strip()
                if clean_item:
                    names.append(clean_item)


def _build_entry(
    file_path: str,
    start_line: int,
    end_line: int,
    lines_with_nums: List[Tuple[int, str]],
) -> Optional[Dict]:
    """Build a structured entry dict from lines."""
    names: List[str] = []
    parents: List[str] = []
    properties: Dict[str, str] = {}
    wikidata_qids: List[Tuple[int, str]] = []

    for line_no, raw_line in lines_with_nums:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        _parse_entry_line(line, line_no, parents, properties, wikidata_qids, names)

    if not names and not wikidata_qids:
        return None

    canonical_name = names[0] if names else "unnamed"
    return {
        "file_path": file_path,
        "taxonomy_type": determine_taxonomy_type(file_path),
        "start_line": start_line,
        "end_line": end_line,
        "canonical_name": canonical_name,
        "names": names,
        "parents": parents,
        "properties": properties,
        "wikidata_qids": wikidata_qids,
    }


def parse_taxonomy_entries(file_path: str, content: Optional[str] = None) -> List[Dict]:
    """
    Parse a taxonomy file into discrete entry blocks with line numbers and parsed fields.
    Each block is separated by blank line(s).
    """
    if content is None:
        content = _read_taxonomy_file(file_path)
        if content is None:
            return []

    blocks = _split_into_blocks(content.splitlines())
    entries = []
    for start_line, end_line, block_lines in blocks:
        entry = _build_entry(file_path, start_line, end_line, block_lines)
        if entry:
            entries.append(entry)

    return entries


def _parse_hunk_header(line: str) -> Optional[int]:
    """Extract starting line number from git diff hunk header @@ -x,y +start,z @@."""
    if not line.startswith("@@ "):
        return None
    match = re.search(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
    return int(match.group(1)) if match else None


def _extract_wikidata_from_diff_line(line: str) -> Optional[str]:
    """Extract QID from an added/modified diff line."""
    if not (line.startswith("+") and not line.startswith("+++")):
        return None
    content = line[1:].strip()
    match = re.search(r"^\s*wikidata(?::[a-zA-Z0-9_-]+)?:\s*([Qq]\d+)\b", content)
    return match.group(1).upper() if match else None


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
        else:
            hunk_line = _parse_hunk_header(line)
            if hunk_line is not None:
                current_new_line = hunk_line
            elif line.startswith("-") and not line.startswith("---"):
                pass  # Deletions do not advance line number in new file
            else:
                qid = _extract_wikidata_from_diff_line(line)
                if qid and current_file and "taxonomies/" in current_file and current_file.endswith(".txt"):
                    new_entries.append({
                        "file_path": current_file,
                        "line_no": current_new_line,
                        "qid": qid,
                    })
                current_new_line += 1

    return new_entries


def _fetch_wikidata_batch(
    qids: List[str],
    props: str,
    languages: Optional[str] = None,
    batch_size: int = 50,
) -> Dict[str, Dict]:
    """Fetch a list of Wikidata QIDs in batches."""
    entities: Dict[str, Dict] = {}
    for i in range(0, len(qids), batch_size):
        batch = qids[i : i + batch_size]
        params = {
            "action": "wbgetentities",
            "ids": "|".join(batch),
            "props": props,
            "format": "json",
        }
        if languages:
            params["languages"] = languages
        url = f"{WIKIDATA_API_URL}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for qid, entity_data in data.get("entities", {}).items():
                    entities[qid] = entity_data
        except Exception as e:
            print(f"Error fetching Wikidata batch {batch}: {e}", file=sys.stderr)
    return entities


def _extract_claim_qids(entities: Dict[str, Dict], property_names: List[str]) -> Set[str]:
    """Extract target entity QIDs from specified properties in claims."""
    class_qids = set()
    for entity in entities.values():
        claims = entity.get("claims", {})
        for prop in property_names:
            for snak in claims.get(prop, []):
                val = snak.get("mainsnak", {}).get("datavalue", {}).get("value")
                if isinstance(val, dict) and "id" in val:
                    class_qids.add(val["id"])
    return class_qids


def _parse_class_info(class_entities: Dict[str, Dict]) -> Dict[str, Dict]:
    """Parse class labels and descriptions."""
    classes = {}
    for cid, centity in class_entities.items():
        en_label = (
            centity.get("labels", {}).get("en", {}).get("value")
            or centity.get("labels", {}).get("fr", {}).get("value")
            or ""
        )
        en_desc = (
            centity.get("descriptions", {}).get("en", {}).get("value")
            or centity.get("descriptions", {}).get("fr", {}).get("value")
            or ""
        )
        classes[cid] = {"label": en_label, "desc": en_desc}
    return classes


def fetch_wikidata_entities(qids: Set[str]) -> Tuple[Dict[str, Dict], Dict[str, Dict]]:
    """
    Batch query the Wikidata API for entities and their P31/P279 classes.
    Returns:
    - entities: dict of QID -> entity data
    - classes: dict of class QID -> {label, desc}
    """
    if not qids:
        return {}, {}

    entities = _fetch_wikidata_batch(
        sorted(qids),
        props="labels|aliases|descriptions|claims|sitelinks",
    )
    class_qids = _extract_claim_qids(entities, ["P31", "P279"])
    class_entities = _fetch_wikidata_batch(
        sorted(class_qids),
        props="labels|descriptions",
        languages="en,fr",
    )
    classes = _parse_class_info(class_entities)
    return entities, classes


def _strip_disambiguation(title: str) -> str:
    """Strip trailing disambiguation like ' (food)' or ' (company)'."""
    if title.endswith(")") and " (" in title:
        prefix, _ = title.rsplit(" (", 1)
        return prefix.rstrip()
    return title


def _collect_entity_candidate_names(entity: Dict) -> List[str]:
    """Collect all Wikidata candidate names from labels, aliases, and sitelinks."""
    candidates = []
    for label_info in entity.get("labels", {}).values():
        val = label_info.get("value")
        if val:
            candidates.append(val)

    for alias_list in entity.get("aliases", {}).values():
        for alias_info in alias_list:
            val = alias_info.get("value")
            if val:
                candidates.append(val)

    for site_info in entity.get("sitelinks", {}).values():
        title = site_info.get("title")
        if title:
            candidates.append(_strip_disambiguation(title))

    return candidates


def _matches_tier1(
    norm_name: str,
    no_space_name: str,
    stripped_name: str,
    norm_c: str,
) -> bool:
    """Check Tier 1 match: exact normalized, no-space, or corporate suffix stripped."""
    if norm_name == norm_c:
        return True
    if no_space_name == norm_c.replace(" ", ""):
        return True
    stripped_c = strip_corporate_suffixes(norm_c)
    return bool(stripped_name and stripped_c and stripped_name == stripped_c)


def _matches_tier2(tokens_name: Set[str], tokens_c: Set[str]) -> bool:
    """Check Tier 2 match: token containment for multi-word or compound names."""
    if not tokens_name or not tokens_c:
        return False
    if tokens_name.issubset(tokens_c) or tokens_c.issubset(tokens_name):
        common = tokens_name & tokens_c
        return any(len(t) >= 4 for t in common) or len(common) >= 2
    return False


def check_name_match(entry_names: List[str], entity: Dict) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Check if any name in entry_names matches any Wikidata label, alias, or Wikipedia title.
    Returns: (matched, matched_entry_name, matched_wikidata_name)
    """
    if not entry_names:
        return False, None, None

    candidates = _collect_entity_candidate_names(entity)
    normalized_candidates = [(c, normalize_string(c)) for c in candidates]

    # Tier 1
    for name in entry_names:
        norm_name = normalize_string(name)
        if not norm_name:
            continue
        no_space = norm_name.replace(" ", "")
        stripped = strip_corporate_suffixes(norm_name)
        for orig_c, norm_c in normalized_candidates:
            if norm_c and _matches_tier1(norm_name, no_space, stripped, norm_c):
                return True, name, orig_c

    # Tier 2
    for name in entry_names:
        tokens_name = get_tokens(normalize_string(name))
        for orig_c, norm_c in normalized_candidates:
            if _matches_tier2(tokens_name, get_tokens(norm_c)):
                return True, name, orig_c

    return False, None, None


def _extract_snak_qids(snaks: List[Dict]) -> List[str]:
    """Extract target entity QIDs from a list of claim snaks."""
    qids = []
    for snak in snaks:
        val = snak.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(val, dict) and "id" in val:
            qids.append(val["id"])
    return qids


def _find_disallowed_concept(
    class_qids: List[str],
    class_info: Dict[str, Dict],
    entity_desc: str,
) -> Optional[Tuple[str, str]]:
    """
    Check for disallowed class QIDs or disallowed keywords in class/entity descriptions.
    Returns: (reason, matched_concept) or None.
    """
    for qid in class_qids:
        info = class_info.get(qid, {})
        label = info.get("label", "")
        desc = info.get("desc", "")
        if qid in DISALLOWED_CLASS_QIDS:
            return (
                f"Disallowed class {label or qid} ({desc or 'unspecified'})",
                label or qid,
            )
        label_desc = f"{label} - {desc}".lower() if label or desc else ""
        for kw in DISALLOWED_CLASS_KEYWORDS:
            if re.search(r"\b" + re.escape(kw) + r"\b", label_desc):
                return (
                    f"Disallowed concept '{kw}' in class {label or qid} ({desc or ''})",
                    label or qid,
                )

    for kw in DISALLOWED_CLASS_KEYWORDS:
        if re.search(r"\b" + re.escape(kw) + r"\b", entity_desc.lower()):
            return (
                f"Disallowed concept '{kw}' in entity description: '{entity_desc}'",
                kw,
            )

    return None


def _find_expected_concept(
    taxonomy_type: str,
    class_qids: List[str],
    class_info: Dict[str, Dict],
    entity_desc: str,
) -> Tuple[bool, Optional[str]]:
    """Check if class or description contains expected keywords for taxonomy domain."""
    expected_kws = EXPECTED_CLASS_KEYWORDS_BY_TYPE.get(taxonomy_type, [])
    if not expected_kws:
        return False, None

    for qid in class_qids:
        info = class_info.get(qid, {})
        label = info.get("label", "")
        desc = info.get("desc", "")
        label_desc = f"{label} {desc}".lower()
        for kw in expected_kws:
            if re.search(r"\b" + re.escape(kw) + r"\b", label_desc):
                matched = f"{label} ({qid})" if label else qid
                return True, matched

    for kw in expected_kws:
        if re.search(r"\b" + re.escape(kw) + r"\b", entity_desc.lower()):
            return True, f"description contains '{kw}'"

    return False, None


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
    p31_qids = _extract_snak_qids(claims.get("P31", []))
    p279_qids = _extract_snak_qids(claims.get("P279", []))
    all_class_qids = p31_qids + p279_qids

    p31_labels = [
        f"{class_info[qid]['label']} ({qid})"
        for qid in all_class_qids
        if qid in class_info and class_info[qid].get("label")
    ]

    entity_desc = (
        entity.get("descriptions", {}).get("en", {}).get("value", "")
        or entity.get("descriptions", {}).get("fr", {}).get("value", "")
    )

    disallowed = _find_disallowed_concept(all_class_qids, class_info, entity_desc)
    if disallowed:
        reason, matched_concept = disallowed
        return {
            "is_disallowed": True,
            "disallowed_reason": reason,
            "is_expected": False,
            "matched_class": matched_concept,
            "p31_labels": p31_labels,
        }

    is_expected, matched_class = _find_expected_concept(taxonomy_type, all_class_qids, class_info, entity_desc)
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

    en_label = (
        entity.get("labels", {}).get("en", {}).get("value")
        or entity.get("labels", {}).get("fr", {}).get("value")
        or "No label"
    )
    en_desc = (
        entity.get("descriptions", {}).get("en", {}).get("value")
        or entity.get("descriptions", {}).get("fr", {}).get("value")
        or "No description"
    )

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
        return validate_git_ref(specified_base)

    # Check GitHub Actions environment
    gh_base = os.environ.get("GITHUB_BASE_REF")
    if gh_base:
        safe_gh = validate_git_ref(gh_base)
        ret = subprocess.run(
            ["git", "rev-parse", "--verify", "--end-of-options", f"origin/{safe_gh}"],
            capture_output=True,
            text=True,
            check=False,
        )
        if ret.returncode == 0:
            return f"origin/{safe_gh}"
        return safe_gh

    # Check origin/main
    ret = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", "origin/main"],
        capture_output=True,
        text=True,
        check=False,
    )
    if ret.returncode == 0:
        return "origin/main"

    # Check main
    ret = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", "main"],
        capture_output=True,
        text=True,
        check=False,
    )
    if ret.returncode == 0:
        return "main"

    return "HEAD~1"


def get_git_diff(base_ref: str, head_ref: Optional[str] = None) -> str:
    """Run git diff against base_ref for taxonomies directory with sanitized refs."""
    safe_base = validate_git_ref(base_ref)
    cmd = ["git", "diff", "-U3", "--end-of-options"]
    if head_ref:
        safe_head = validate_git_ref(head_ref)
        cmd.append(f"{safe_base}...{safe_head}")
    else:
        cmd.append(safe_base)
    cmd.extend(["--", "taxonomies/"])

    ret = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if ret.returncode != 0:
        print(f"Warning: git diff returned non-zero code {ret.returncode}: {ret.stderr}", file=sys.stderr)
        return ""
    return ret.stdout


def _collect_file_entries(
    file_path: str,
    check_all: bool,
    base_ref: Optional[str],
    head_ref: Optional[str],
) -> List[Dict]:
    """Collect entries to check when --file is provided."""
    safe_path = safe_resolve_path(file_path)
    parsed_entries = parse_taxonomy_entries(safe_path)
    if check_all:
        entries = []
        for entry in parsed_entries:
            for line_no, qid in entry["wikidata_qids"]:
                entries.append({
                    "file_path": file_path,
                    "line_no": line_no,
                    "qid": qid,
                    "taxonomy_type": entry["taxonomy_type"],
                    "canonical_name": entry["canonical_name"],
                    "names": entry["names"],
                })
        return entries

    base = find_git_base_ref(base_ref)
    diff_text = get_git_diff(base, head_ref)
    diff_entries = parse_git_diff_for_new_wikidata(diff_text)
    abs_target = os.path.abspath(safe_path)
    diff_entries = [e for e in diff_entries if os.path.abspath(safe_resolve_path(e["file_path"])) == abs_target]

    entries = []
    for de in diff_entries:
        target_block = next(
            (b for b in parsed_entries if b["start_line"] <= de["line_no"] <= b["end_line"]),
            None,
        )
        entries.append({
            "file_path": de["file_path"],
            "line_no": de["line_no"],
            "qid": de["qid"],
            "taxonomy_type": target_block["taxonomy_type"] if target_block else determine_taxonomy_type(de["file_path"]),
            "canonical_name": target_block["canonical_name"] if target_block else "unknown",
            "names": target_block["names"] if target_block else [],
        })
    return entries


def _collect_diff_entries(base_ref: Optional[str], head_ref: Optional[str]) -> List[Dict]:
    """Collect entries to check from git diff against base_ref."""
    base = find_git_base_ref(base_ref)
    print(f"Comparing against git base: {base}")
    diff_text = get_git_diff(base, head_ref)
    diff_entries = parse_git_diff_for_new_wikidata(diff_text)

    file_entries_cache: Dict[str, List[Dict]] = {}
    entries = []
    for de in diff_entries:
        fpath = de["file_path"]
        if fpath not in file_entries_cache:
            file_entries_cache[fpath] = parse_taxonomy_entries(fpath)
        parsed_blocks = file_entries_cache[fpath]

        target_block = next(
            (b for b in parsed_blocks if b["start_line"] <= de["line_no"] <= b["end_line"]),
            None,
        )
        entries.append({
            "file_path": fpath,
            "line_no": de["line_no"],
            "qid": de["qid"],
            "taxonomy_type": target_block["taxonomy_type"] if target_block else determine_taxonomy_type(fpath),
            "canonical_name": target_block["canonical_name"] if target_block else "unknown",
            "names": target_block["names"] if target_block else [],
        })
    return entries


def _validate_all_entries(entries_to_check: List[Dict]) -> Tuple[List[Dict], bool]:
    """Fetch Wikidata entities and validate all entries."""
    qids = {e["qid"] for e in entries_to_check}
    print(f"Querying Wikidata for {len(qids)} unique entities...")
    entities, class_info = fetch_wikidata_entities(qids)

    results = []
    has_errors = False
    for entry in entries_to_check:
        entity = entities.get(entry["qid"])
        res = validate_wikidata_entry(entry, entity, class_info)
        results.append(res)
        if res["status"] == "ERROR":
            has_errors = True

    return results, has_errors


def _print_results(results: List[Dict]) -> None:
    """Print formatted validation results to console and GitHub annotations."""
    print("\n" + "=" * 60)
    print("WIKIDATA VALIDATION RESULTS")
    print("=" * 60)

    for r in results:
        status_symbol = "✅" if r["status"] == "PASS" else "❌"
        print(f"{status_symbol} [{r['file']}:{r['line']}] {r['entry_name']} -> {r['qid']}")
        print(f"   Wikidata: {r['entity_label']} - {r['entity_desc']}")
        print(f"   Result:   {r['message']}\n")

        if r["status"] == "ERROR":
            print(f"::error file={r['file']},line={r['line']}::[Wikidata Check] {r['message']}")


def _write_step_summary(results: List[Dict]) -> None:
    """Write validation summary table into GITHUB_STEP_SUMMARY."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path or summary_path.startswith("-"):
        return
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


def main():
    parser = argparse.ArgumentParser(description="Check newly added or modified Wikidata entries in taxonomies.")
    parser.add_argument("--base", help="Git base reference (default: auto-detected, e.g. origin/main)")
    parser.add_argument("--head", help="Git head reference (default: working tree / HEAD)")
    parser.add_argument("--file", help="Check a specific taxonomy file directly")
    parser.add_argument("--all", action="store_true", help="When using --file, check all entries in the file")
    parser.add_argument("--dry-run", action="store_true", help="Parse diff and print entries without calling Wikidata API")
    args = parser.parse_args()

    safe_base = validate_git_ref(args.base) if args.base else None
    safe_head = validate_git_ref(args.head) if args.head else None

    if args.file:
        entries_to_check = _collect_file_entries(args.file, args.all, safe_base, safe_head)
    else:
        entries_to_check = _collect_diff_entries(safe_base, safe_head)

    if not entries_to_check:
        print("✅ No new or modified Wikidata entries found in taxonomies.")
        sys.exit(0)

    print(f"Found {len(entries_to_check)} new/modified Wikidata entries to verify.")
    for e in entries_to_check:
        print(f"  - {e['file_path']}:{e['line_no']} -> {e['qid']} ({e['canonical_name']})")

    if args.dry_run:
        print("Dry run requested; skipping API calls.")
        sys.exit(0)

    results, has_errors = _validate_all_entries(entries_to_check)
    _print_results(results)
    _write_step_summary(results)

    if has_errors:
        print("❌ Wikidata validation failed! Please fix the errors above.")
        sys.exit(1)

    print("🎉 All new Wikidata mappings verified successfully!")
    sys.exit(0)


if __name__ == "__main__":
    main()
