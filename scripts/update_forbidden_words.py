#!/usr/bin/env python3
"""
Open Food Facts - Forbidden Words Fetcher / Updater
Downloads and compiles curated bad word lists from external community repositories
(e.g. LDNOOBW as referenced in GitHub Issue #1025) into a local uncommitted file.

Usage:
    # Fetch default languages (fr, en, es, de, it) into conf/forbidden_words.txt:
    python3 scripts/update_forbidden_words.py

    # Fetch specific languages:
    python3 scripts/update_forbidden_words.py --languages fr,en,es,de,it,pt,nl

    # Custom output path:
    python3 scripts/update_forbidden_words.py --output conf/forbidden_words.txt
"""

import argparse
from pathlib import Path
import re
import sys
import unicodedata
import urllib.error
import urllib.request
from typing import Dict, List, Optional, Set

DEFAULT_LANGUAGES = [
    "ar", "cs", "da", "de", "en", "eo", "es", "fa", "fi", "fil", "fr",
    "hi", "hu", "it", "ja", "kab", "ko", "nl", "no", "pl", "pt", "ru",
    "sv", "th", "tr", "zh"
]

# Primary source repository from Issue #1025:
# https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
LDNOOBW_BASE_URL = (
    "https://raw.githubusercontent.com/LDNOOBW/"
    "List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/{lang}"
)

# Secondary source from Issue #1025 for username / universal vandalism:
# https://github.com/marteinn/The-Big-Username-Blacklist
USERNAME_BLACKLIST_URL = (
    "https://raw.githubusercontent.com/marteinn/"
    "The-Big-Username-Blacklist/master/list_raw.txt"
)

# Essential multi-word phrases that may not be in single-word lists
BASELINE_WORDS = {
    "xx": ["dickhead", "motherfucker", "bullshit", "asshole"],
    "es": ["hijo de puta", "hija de puta", "mierda", "gilipollas", "cono"],
    "fr": ["fils de pute", "fille de pute", "nique ta mere", "trou du cul", "sac a merde", "batard", "encule", "enculer"],
    "en": ["dickhead", "motherfucker", "cum", "anus", "bullshit"],
    "it": ["figlio di puttana", "stronzo", "cazzo"],
}



def normalize_term(s: str) -> str:
    """Normalize term for deduplication and comparison."""
    nfkd = unicodedata.normalize("NFKD", s.strip())
    clean = "".join(c for c in nfkd if not unicodedata.combining(c)).lower()
    return re.sub(r"[\s\-_]+", " ", clean).strip()


def load_allowlist_patterns(allowlist_path: Path) -> Set[str]:
    """Load exclusion patterns from the allowlist to prevent importing false positives."""
    excluded: Set[str] = set()
    if not allowlist_path.is_file():
        return excluded

    current_section = None
    try:
        with open(allowlist_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    current_section = line[1:-1].strip().lower()
                    continue
                if current_section == "patterns":
                    pat = line.split("#")[0].strip()
                    if pat:
                        excluded.add(normalize_term(pat))
    except Exception as e:
        sys.stderr.write(f"Warning: could not read allowlist {allowlist_path}: {e}\n")

    return excluded


def fetch_remote_words(url: str, timeout: int = 15) -> List[str]:
    """Fetch lines of text from an external HTTP/HTTPS URL."""
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "OpenFoodFacts-ForbiddenWords-Updater/1.0"}
    )
    words = []
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            content = response.read().decode("utf-8", errors="replace")
            for line in content.splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    words.append(line)
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"  HTTP error {e.code} fetching {url}\n")
    except urllib.error.URLError as e:
        sys.stderr.write(f"  Network error fetching {url}: {e.reason}\n")
    except Exception as e:
        sys.stderr.write(f"  Error fetching {url}: {e}\n")

    return words


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download and compile forbidden words from external repositories (e.g. LDNOOBW).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        "-l", "--languages", default=",".join(DEFAULT_LANGUAGES),
        help=f"Comma-separated list of language codes to download (default: {','.join(DEFAULT_LANGUAGES)})."
    )
    parser.add_argument(
        "-o", "--output", default=None,
        help="Target output file path (default: conf/forbidden_words.txt)."
    )
    parser.add_argument(
        "-a", "--allowlist", default=None,
        help="Path to allowlist file with terms to exclude (default: conf/forbidden_words_allowlist.txt)."
    )
    parser.add_argument(
        "--source-url-template", default=LDNOOBW_BASE_URL,
        help="URL template for language word lists, using {lang} placeholder."
    )
    parser.add_argument(
        "--include-username-blacklist", action="store_true",
        help="Also fetch universal slurs from The-Big-Username-Blacklist."
    )

    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    output_path = Path(args.output) if args.output else repo_root / "conf" / "forbidden_words.txt"
    allowlist_path = Path(args.allowlist) if args.allowlist else repo_root / "conf" / "forbidden_words_allowlist.txt"

    if args.languages.strip().lower() == "all":
        languages = list(DEFAULT_LANGUAGES)
    else:
        languages = [lang.strip().lower() for lang in args.languages.split(",") if lang.strip()]

    print(f"Loading allowlist patterns from: {allowlist_path}")
    excluded_patterns = load_allowlist_patterns(allowlist_path)
    print(f"Loaded {len(excluded_patterns)} allowlist exclusion terms.")

    words_by_lang: Dict[str, List[str]] = {}
    total_downloaded = 0
    total_excluded = 0

    for lang in languages:
        url = args.source_url_template.format(lang=lang)
        print(f"Fetching '{lang}' words from: {url}")
        raw_words = fetch_remote_words(url)
        filtered = []
        for word in raw_words:
            norm = normalize_term(word)
            if not norm or len(norm) < 3:
                continue
            if norm in excluded_patterns:
                total_excluded += 1
                continue
            filtered.append(word.strip().lower())

        words_by_lang[lang] = sorted(set(filtered))
        total_downloaded += len(words_by_lang[lang])
        print(f"  -> Got {len(words_by_lang[lang])} unique words for '{lang}'.")

    if args.include_username_blacklist:
        print(f"Fetching universal slurs from: {USERNAME_BLACKLIST_URL}")
        user_words = fetch_remote_words(USERNAME_BLACKLIST_URL)
        xx_list = []
        for w in user_words:
            norm = normalize_term(w)
            if norm and len(norm) >= 4 and norm not in excluded_patterns:
                xx_list.append(w.strip().lower())
        words_by_lang["xx"] = sorted(set(xx_list))
        print(f"  -> Got {len(words_by_lang['xx'])} universal blacklist words.")
        total_downloaded += len(words_by_lang["xx"])

    # Merge baseline words (universal slurs and essential phrases)
    for lang, b_words in BASELINE_WORDS.items():
        existing = {normalize_term(w) for w in words_by_lang.get(lang, [])}
        for bw in b_words:
            norm = normalize_term(bw)
            if norm not in excluded_patterns and norm not in existing:
                words_by_lang.setdefault(lang, []).append(bw)
                existing.add(norm)
                total_downloaded += 1
        words_by_lang[lang] = sorted(set(words_by_lang[lang]))

    if total_downloaded == 0:
        sys.stderr.write("Error: No words were successfully downloaded. Please check network connection.\n")
        return 1

    # Write output file
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("# ==============================================================================\n")
        f.write("# Open Food Facts - Forbidden Words (Automatically Compiled)\n")
        f.write(f"# Source: {args.source_url_template}\n")
        f.write("# This file is gitignored so offensive words are not committed to git.\n")
        f.write("# ==============================================================================\n\n")

        for lang, words in sorted(words_by_lang.items()):
            f.write(f"# Language: {lang} ({len(words)} words)\n")
            for word in words:
                f.write(f"{lang}: {word}\n")
            f.write("\n")

    print(f"\nSuccessfully wrote {total_downloaded} forbidden words to: {output_path}")
    print(f"Filtered out {total_excluded} terms matching the allowlist.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
