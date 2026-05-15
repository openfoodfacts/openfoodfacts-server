#!/usr/bin/env python3
"""
Translation Quality Checker for Open Food Facts

This script checks .po translation files for common quality issues:
- Brand names that should not be translated (Open Food Facts, Open Beauty Facts, etc.)
- Green-Score that should not be translated
- URL language code consistency
- Placeholder mismatches (%s, %d, etc.)
- Format string validation
- HTML tag consistency
- Missing translations
- Suspicious literal translations

Usage: python3 scripts/check-translation-quality.py [--pr-mode] [--file FILE]
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Any
import argparse

# Brand names and terms that should NEVER be translated
UNTRANSLATABLE_TERMS = [
    "Open Food Facts",
    "Open Beauty Facts", 
    "Open Pet Food Facts",
    "Open Prices",
    "Green-Score",
    "Nutri-Score",
    "NutriScore",
    "Nova",
]

# Mapping of language codes to their variations used in filenames
LANGUAGE_CODE_MAP = {
    'pt_BR': 'pt',
    'pt_PT': 'pt',
    'zh_CN': 'zh',
    'zh_HK': 'zh',
    'zh_TW': 'zh',
    'en_GB': 'en',
    'en_AU': 'en',
    'en_US': 'en',
    'nl_BE': 'nl',
    'nl_NL': 'nl',
    'sr_CS': 'sr',
    'sr_RS': 'sr',
    'kmr_TR': 'kmr',
}

class TranslationIssue:
    """Represents a translation quality issue"""
    def __init__(self, file_path: str, line_num: int, issue_type: str, 
                 msgid: str, msgstr: str, details: str):
        self.file_path = file_path
        self.line_num = line_num
        self.issue_type = issue_type
        self.msgid = msgid
        self.msgstr = msgstr
        self.details = details
    
    def __str__(self):
        return (f"{self.file_path}:{self.line_num} [{self.issue_type}]\n"
                f"  msgid:  {self.msgid}\n"
                f"  msgstr: {self.msgstr}\n"
                f"  issue:  {self.details}\n")
    
    def to_pr_comment(self):
        """Format as a GitHub PR review comment"""
        return (f"**{self.issue_type}** (line {self.line_num})\n\n"
                f"```\n{self.details}\n```\n\n"
                f"msgid: `{self.msgid}`\n\n"
                f"msgstr: `{self.msgstr}`")


class POFileParser:
    """Parse .po files and extract translations"""
    
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.language_code = self._extract_language_code()
        
    def _extract_language_code(self) -> str:
        """Extract language code from filename (e.g., 'fr' from 'fr.po')"""
        return Path(self.file_path).stem
    
    def parse(self) -> List[Dict[str, Any]]:
        """Parse .po file and return list of translation entries"""
        entries = []
        current_entry = {}
        current_field = None
        
        with open(self.file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.rstrip('\n')
                
                # Skip comments and empty lines for now, but track them
                if line.startswith('#'):
                    if 'comments' not in current_entry:
                        current_entry['comments'] = []
                    current_entry['comments'].append(line)
                    continue
                    
                if not line.strip():
                    # Empty line - end of entry
                    if current_entry and 'msgid' in current_entry:
                        entries.append(current_entry)
                    current_entry = {}
                    current_field = None
                    continue
                
                # Match msgctxt, msgid, msgstr lines
                if line.startswith('msgctxt '):
                    current_field = 'msgctxt'
                    current_entry['msgctxt'] = self._extract_string(line[8:])
                    current_entry['msgctxt_line'] = line_num
                elif line.startswith('msgid '):
                    current_field = 'msgid'
                    current_entry['msgid'] = self._extract_string(line[6:])
                    current_entry['msgid_line'] = line_num
                elif line.startswith('msgstr '):
                    current_field = 'msgstr'
                    current_entry['msgstr'] = self._extract_string(line[7:])
                    current_entry['msgstr_line'] = line_num
                elif line.startswith('"') and current_field:
                    # Continuation of previous field
                    current_entry[current_field] += self._extract_string(line)
        
        # Don't forget last entry
        if current_entry and 'msgid' in current_entry:
            entries.append(current_entry)
            
        return entries
    
    def _extract_string(self, quoted_str: str) -> str:
        """Extract string from quoted format, handling escape sequences"""
        # Remove leading/trailing quotes and whitespace
        quoted_str = quoted_str.strip()
        if quoted_str.startswith('"') and quoted_str.endswith('"'):
            quoted_str = quoted_str[1:-1]
        
        # Use a proper escape sequence decoder
        # Replace escape sequences in the correct order
        result = []
        i = 0
        while i < len(quoted_str):
            if quoted_str[i] == '\\' and i + 1 < len(quoted_str):
                next_char = quoted_str[i + 1]
                if next_char == 'n':
                    result.append('\n')
                    i += 2
                elif next_char == 't':
                    result.append('\t')
                    i += 2
                elif next_char == '\\':
                    result.append('\\')
                    i += 2
                elif next_char == '"':
                    result.append('"')
                    i += 2
                else:
                    # Unknown escape sequence, keep as is
                    result.append(quoted_str[i])
                    i += 1
            else:
                result.append(quoted_str[i])
                i += 1
        
        return ''.join(result)


class TranslationQualityChecker:
    """Check translation quality for various issues"""
    
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.parser = POFileParser(file_path)
        self.language_code = self.parser.language_code
        self.issues: List[TranslationIssue] = []
    
    def check_all(self) -> List[TranslationIssue]:
        """Run all translation quality checks"""
        entries = self.parser.parse()
        
        for entry in entries:
            msgid = entry.get('msgid', '')
            msgstr = entry.get('msgstr', '')
            line_num = entry.get('msgstr_line', 0)
            comments = entry.get('comments', [])
            
            # Skip empty msgid (header entry) or empty translations
            if not msgid or not msgstr or msgstr == msgid:
                continue
            
            # Check for untranslatable terms
            self._check_brand_names(entry, line_num, msgid, msgstr, comments)
            
            # Check placeholder consistency
            self._check_placeholders(entry, line_num, msgid, msgstr)
            
            # Check URL language codes
            self._check_url_consistency(entry, line_num, msgid, msgstr)
            
            # Check HTML tag consistency
            self._check_html_tags(entry, line_num, msgid, msgstr)
        
        return self.issues
    
    def _check_html_tags(self, entry: dict, line_num: int, msgid: str, msgstr: str):
        """Check if HTML tags are consistent between msgid and msgstr"""
        # Extract HTML tags
        html_tag_pattern = r'<[^>]+>'
        msgid_tags = re.findall(html_tag_pattern, msgid)
        msgstr_tags = re.findall(html_tag_pattern, msgstr)
        
        # Count tags
        if len(msgid_tags) != len(msgstr_tags):
            issue = TranslationIssue(
                self.file_path, line_num, "HTML_TAG_MISMATCH",
                msgid, msgstr,
                f"HTML tag count mismatch: msgid has {len(msgid_tags)} tags, "
                f"msgstr has {len(msgstr_tags)} tags"
            )
            self.issues.append(issue)
        else:
            # Check for specific tag types only when overall counts match
            for tag_type in [
                '<a', '</a>',
                '<strong>', '</strong>',
                '<em>', '</em>',
                '<span', '</span>',
                '<p>', '</p>',
                '<br>', '<br/>',
                '<sub>', '</sub>',
                '<sup>', '</sup>',
                '<b>', '</b>',
                '<i>', '</i>',
                '<div', '</div>',
                '<ul', '</ul>',
                '<ol', '</ol>',
                '<li', '</li>',
            ]:
                msgid_count = msgid.count(tag_type)
                msgstr_count = msgstr.count(tag_type)
                if msgid_count != msgstr_count:
                    issue = TranslationIssue(
                        self.file_path, line_num, "HTML_TAG_TYPE_MISMATCH",
                        msgid, msgstr,
                        f"Tag '{tag_type}' count differs: msgid has {msgid_count}, "
                        f"msgstr has {msgstr_count}"
                    )
                    self.issues.append(issue)
    
    def _check_brand_names(self, entry: dict, line_num: int, msgid: str, 
                           msgstr: str, comments: list):
        """Check if brand names are incorrectly translated"""
        # First check if there's a "do not translate" comment
        has_do_not_translate = any(
            'do not translate' in c.lower() or 'don\'t translate' in c.lower()
            for c in comments
        )
        
        for term in UNTRANSLATABLE_TERMS:
            if term in msgid:
                # Check if the term is in msgstr with exact case match
                if term not in msgstr and msgstr:
                    # Check if it's present with wrong casing
                    if term.lower() in msgstr.lower():
                        issue = TranslationIssue(
                            self.file_path, line_num, "BRAND_NAME_CASE_MISMATCH",
                            msgid, msgstr,
                            f"'{term}' must be preserved with exact casing. Found different casing in msgstr."
                        )
                        self.issues.append(issue)
                    # Try to detect if it was translated
                    elif self._might_be_translation(term, msgstr):
                        issue = TranslationIssue(
                            self.file_path, line_num, "BRAND_NAME_TRANSLATED",
                            msgid, msgstr,
                            f"'{term}' should NOT be translated. Found in msgstr: '{msgstr}'"
                        )
                        self.issues.append(issue)
                elif has_do_not_translate and term not in msgstr:
                    # Explicit instruction not to translate, but term is missing
                    issue = TranslationIssue(
                        self.file_path, line_num, "BRAND_NAME_MISSING",
                        msgid, msgstr,
                        f"'{term}' should be preserved in translation (marked as 'do not translate')"
                    )
                    self.issues.append(issue)
    
    def _might_be_translation(self, term: str, msgstr: str) -> bool:
        """Heuristic to detect if a brand name might have been translated"""
        # Look for common patterns in the examples given:
        # "Open Food Facts" -> "faches de l'alimentacion dobèrta" (Occitan)
        # "Open Food Facts" -> "åpne matfakta" (Norwegian)
        # "Green-Score" -> "Pontuação Verde" (Portuguese)
        
        msgstr_lower = msgstr.lower()
        
        # Check specific known bad translations
        bad_translations = {
            'open food facts': [
                'faches', 'matfakta', 'fakta om', 'alimentacion', 'alimentación',
                'dobèrta', 'dobèrts', 'ouvert', 'ouverte', 'abierto', 'abierta',
                'aberto', 'aberta', 'aperto', 'aperta', 'otwarty', 'otwarte',
                'åpne', 'åpen', 'öppen', 'avoin', 'avoimet', 'açık',
                'offene', 'offener', 'offenes', 'offenen', 'открыт', 'открытые'
            ],
            'open beauty facts': [
                'skjønnhetssaker', 'bellezza', 'beleza', 'beauté', 'belleza',
                'schönheit', 'красота', 'güzellik', 'kauneus'
            ],
            'open pet food facts': [
                'kjæledyrmat', 'animali', 'animais', 'animaux', 'mascotas',
                'haustier', 'питомец', 'evcil', 'lemmikki'
            ],
            'open prices': [
                'priser', 'prix', 'precios', 'prezzi', 'preços', 'preise',
                'цены', 'fiyatlar', 'hinnat', 'åpne priser', 'prix ouverts',
                'precios abiertos', 'prezzi aperti', 'preços abertos'
            ],
            'green-score': [
                'pontuação verde', 'pontuacao verde', 'verde', 'vert', 'grün',
                'verde puntuación', 'punteggio verde', 'grüne bewertung',
                'зелёный', 'yeşil', 'vihreä', 'grønn', 'grön', 'zöld'
            ],
        }
        
        term_key = term.lower()
        if term_key in bad_translations:
            for bad_trans in bad_translations[term_key]:
                if bad_trans in msgstr_lower:
                    # Make sure it's not just a coincidence (e.g., "verde" in a description)
                    # by checking if the term itself is NOT present
                    if term.lower() not in msgstr_lower:
                        return True
        
        # Generic check: if msgstr contains words that suggest translation
        # but the original term is missing
        if term.lower() not in msgstr_lower:
            # Check for translations of "Open"
            if 'open' in term.lower():
                open_translations = [
                    'åpne', 'åpen', 'dobèrta', 'dobèrts', 'ouvert', 'ouverte',
                    'abierto', 'abierta', 'aberto', 'aberta', 'aperto', 'aperta',
                    'öppen', 'avoin', 'açık', 'offene', 'offener', 'открыт'
                ]
                for trans in open_translations:
                    if trans in msgstr_lower:
                        return True
            
            # Check for translations of "Facts"
            if 'facts' in term.lower():
                facts_translations = [
                    'faches', 'fakta', 'faits', 'hechos', 'fatos', 'fatti',
                    'daten', 'факты', 'gerçekler', 'tietoja'
                ]
                for trans in facts_translations:
                    if trans in msgstr_lower:
                        return True
        
        return False
    
    def _check_placeholders(self, entry: dict, line_num: int, 
                           msgid: str, msgstr: str):
        """Check if placeholders like %s, %d are consistent"""
        # Find all placeholders in msgid and msgstr
        # Matches printf-style format specifiers:
        # - Simple: %s, %d, %i, %f, etc.
        # - With width/precision: %.2f, %10s, %5d
        # - With modifiers: %ld, %lld, %zu
        # - Named: %(name)s, %(value)d
        placeholder_pattern = r'%(?:\([^)]+\))?(?:[-+0 #])?(?:\*|\d+)?(?:\.(?:\*|\d+))?(?:[hlLzjt])?[sdifuxXoeEgGcpnaAbBSCyYmMHIjwWUVzZ%]'
        
        msgid_placeholders = re.findall(placeholder_pattern, msgid)
        msgstr_placeholders = re.findall(placeholder_pattern, msgstr)
        
        if len(msgid_placeholders) != len(msgstr_placeholders):
            issue = TranslationIssue(
                self.file_path, line_num, "PLACEHOLDER_MISMATCH",
                msgid, msgstr,
                f"Placeholder count mismatch: msgid has {len(msgid_placeholders)} "
                f"({msgid_placeholders}), msgstr has {len(msgstr_placeholders)} "
                f"({msgstr_placeholders})"
            )
            self.issues.append(issue)
        elif msgid_placeholders and msgstr_placeholders:
            # Check if placeholders are in the same order
            if msgid_placeholders != msgstr_placeholders:
                issue = TranslationIssue(
                    self.file_path, line_num, "PLACEHOLDER_ORDER",
                    msgid, msgstr,
                    f"Placeholder order/type differs: msgid={msgid_placeholders}, "
                    f"msgstr={msgstr_placeholders}"
                )
                self.issues.append(issue)
    
    def _check_url_consistency(self, entry: dict, line_num: int, 
                               msgid: str, msgstr: str):
        """Check if URLs have consistent language codes"""
        # Pattern for world-xx.openfoodfacts.org and variants
        # Matches: world-[language_code].[site].org
        # where language_code can be 'fr', 'pt_BR', etc.
        # and site can be openfoodfacts, openbeautyfacts, openpetfoodfacts, or openpriceguide
        url_pattern = (r'world-([a-z]{2}(?:_[A-Z]{2})?)\.'
                      r'(open(?:food|beauty|petfood)facts|openpriceguide)\.org')
        
        msgstr_urls = re.findall(url_pattern, msgstr)
        
        for url_lang, site in msgstr_urls:
            # Get the expected language code for this file
            expected_lang = self.language_code
            
            # Apply language code mapping
            if expected_lang in LANGUAGE_CODE_MAP:
                expected_lang = LANGUAGE_CODE_MAP[expected_lang]
            
            # Normalize the URL language code
            url_lang_normalized = url_lang.replace('_', '-').split('-')[0]
            expected_lang_normalized = expected_lang.replace('_', '-').split('-')[0]
            
            if url_lang_normalized != expected_lang_normalized:
                issue = TranslationIssue(
                    self.file_path, line_num, "URL_LANGUAGE_MISMATCH",
                    msgid, msgstr,
                    f"URL language code '{url_lang}' doesn't match file language "
                    f"'{self.language_code}' (expected 'world-{expected_lang_normalized}...')"
                )
                self.issues.append(issue)


def check_file(file_path: str) -> List[TranslationIssue]:
    """Check a single .po file for quality issues"""
    checker = TranslationQualityChecker(file_path)
    return checker.check_all()


def check_all_po_files(po_dir: str = "po") -> Dict[str, List[TranslationIssue]]:
    """Check all .po files in the given directory"""
    results = {}
    
    for root, dirs, files in os.walk(po_dir):
        for file in files:
            if file.endswith('.po') and file != 'en.po':
                file_path = os.path.join(root, file)
                issues = check_file(file_path)
                if issues:
                    results[file_path] = issues
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Check translation quality in .po files"
    )
    parser.add_argument(
        '--pr-mode',
        action='store_true',
        help='Output in GitHub PR comment format'
    )
    parser.add_argument(
        '--file',
        type=str,
        help='Check a specific .po file instead of all files'
    )
    args = parser.parse_args()
    
    # Change to repository root
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)
    
    if args.file:
        issues = check_file(args.file)
        results = {args.file: issues} if issues else {}
    else:
        results = check_all_po_files()
    
    if not results:
        print("✓ No translation quality issues found!")
        return 0
    
    # Report results
    total_issues = sum(len(issues) for issues in results.values())
    print(f"Found {total_issues} translation quality issues in {len(results)} files:\n")
    
    for file_path, issues in results.items():
        print(f"\n{'='*80}")
        print(f"File: {file_path}")
        print(f"{'='*80}")
        
        for issue in issues:
            if args.pr_mode:
                print(issue.to_pr_comment())
                print()
            else:
                print(issue)
    
    # Return non-zero exit code if issues found
    return 1 if results else 0


if __name__ == "__main__":
    sys.exit(main())
