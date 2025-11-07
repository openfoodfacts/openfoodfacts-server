#!/usr/bin/env python3
"""
Extract all link translations from .po files and generate symlink commands for openfoodfacts-web.

This script parses all .po files in po/common/ directory to find msgctxt entries ending with "_link",
and generates shell commands to create symlinks for translated page names.

The symlinks are created in the following patterns:
- lang/xx/texts/translated_pagename.html -> pagename.html (relative link in same directory)
- lang/opf/xx/texts/translated_pagename.html -> pagename.html (relative link in same directory)
- lang/obf/xx/texts/translated_pagename.html -> pagename.html (relative link in same directory)
- lang/opff/xx/texts/translated_pagename.html -> pagename.html (relative link in same directory)

Where:
- xx is the language code (e.g., fr, de, es)
- pagename is the English page name (from msgid, without leading /)
- translated_pagename is the translated page name (from msgstr, without leading /)

Usage:
    python scripts/generate_symlinks_for_translated_pages.py [--output FILE]

Options:
    --output FILE    Write output to FILE instead of stdout (default: stdout)
    --help           Show this help message
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple


class POFileParser:
    """Simple parser for .po files to extract link translations."""
    
    def __init__(self, filepath: str):
        self.filepath = filepath
        
    def parse(self) -> List[Tuple[str, str, str]]:
        """
        Parse .po file and extract entries with msgctxt ending in "_link".
        
        Returns:
            List of tuples (msgctxt, msgid, msgstr)
        """
        entries = []
        current_msgctxt = None
        current_msgid = None
        current_msgstr = None
        in_msgctxt = False
        in_msgid = False
        in_msgstr = False
        
        with open(self.filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                
                # Start of msgctxt
                if line.startswith('msgctxt '):
                    # Save previous entry if it was a link
                    if current_msgctxt and current_msgctxt.endswith('_link') and current_msgid and current_msgstr:
                        entries.append((current_msgctxt, current_msgid, current_msgstr))
                    
                    current_msgctxt = line[8:].strip().strip('"')
                    current_msgid = None
                    current_msgstr = None
                    in_msgctxt = True
                    in_msgid = False
                    in_msgstr = False
                
                # Start of msgid
                elif line.startswith('msgid '):
                    current_msgid = line[6:].strip().strip('"')
                    in_msgctxt = False
                    in_msgid = True
                    in_msgstr = False
                
                # Start of msgstr
                elif line.startswith('msgstr '):
                    current_msgstr = line[7:].strip().strip('"')
                    in_msgctxt = False
                    in_msgid = False
                    in_msgstr = True
                
                # Continuation of multiline strings
                elif line.startswith('"'):
                    content = line.strip('"')
                    if in_msgctxt and current_msgctxt is not None:
                        current_msgctxt += content
                    elif in_msgid and current_msgid is not None:
                        current_msgid += content
                    elif in_msgstr and current_msgstr is not None:
                        current_msgstr += content
        
        # Save last entry if it was a link
        if current_msgctxt and current_msgctxt.endswith('_link') and current_msgid and current_msgstr:
            entries.append((current_msgctxt, current_msgid, current_msgstr))
        
        return entries


def extract_all_links(po_dir: str) -> Dict[str, List[Tuple[str, str, str]]]:
    """
    Extract all link translations from all .po files.
    
    Args:
        po_dir: Directory containing .po files
        
    Returns:
        Dictionary mapping language code to list of (msgctxt, msgid, msgstr) tuples
    """
    results = {}
    po_files = Path(po_dir).glob('*.po')
    
    for po_file in sorted(po_files):
        lang_code = po_file.stem
        parser = POFileParser(str(po_file))
        entries = parser.parse()
        
        if entries:
            results[lang_code] = entries
    
    return results


def generate_symlink_commands(links_data: Dict[str, List[Tuple[str, str, str]]]) -> List[str]:
    """
    Generate shell commands to create symlinks for translated pages.
    
    Args:
        links_data: Dictionary mapping language code to list of (msgctxt, msgid, msgstr) tuples
        
    Returns:
        List of shell commands to create symlinks
    """
    commands = []
    commands.append("#!/bin/bash")
    commands.append("# Auto-generated symlinks for translated page names")
    commands.append("# Generated from openfoodfacts-server .po files")
    commands.append("")
    commands.append("# This script creates symlinks for translated page names in openfoodfacts-web")
    commands.append("# Run this script in the openfoodfacts-web repository root directory")
    commands.append("")
    
    # Prefixes for different product databases
    prefixes = ['', 'opf/', 'obf/', 'opff/']
    
    for lang_code, entries in sorted(links_data.items()):
        # Skip English since it's the base language
        if lang_code == 'en':
            continue
            
        for msgctxt, msgid, msgstr in entries:
            # Only process local page links (starting with /)
            if not msgid.startswith('/'):
                continue
                
            # Skip empty translations
            if not msgstr or msgstr == msgid:
                continue
            
            # Skip if msgstr doesn't start with /
            if not msgstr.startswith('/'):
                continue
            
            # Remove leading slashes
            msgid_clean = msgid.lstrip('/')
            msgstr_clean = msgstr.lstrip('/')
            
            # Skip if they're the same after cleaning
            if msgid_clean == msgstr_clean:
                continue
            
            # Skip if the path contains special characters that aren't suitable for filenames
            # This filters out things like "Permanent link to..." and placeholder strings
            if any(char in msgstr_clean for char in ['%', '?', '&', '=', ' ']):
                continue
            
            # Generate symlink commands for each prefix
            for prefix in prefixes:
                source = f"lang/{prefix}{lang_code}/texts/{msgstr_clean}.html"
                target = f"{msgid_clean}.html"
                
                # Create directory if needed and symlink
                dir_path = f"lang/{prefix}{lang_code}/texts"
                commands.append(f"mkdir -p {dir_path}")
                commands.append(f"ln -sf {target} {source}")
    
    return commands


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    args = parser.parse_args()
    
    # Find the po/common directory
    script_dir = Path(__file__).parent
    repo_dir = script_dir.parent
    po_dir = repo_dir / 'po' / 'common'
    
    if not po_dir.exists():
        print(f"Error: Directory {po_dir} not found", file=sys.stderr)
        sys.exit(1)
    
    # Extract all links
    print(f"Extracting links from {po_dir}...", file=sys.stderr)
    links_data = extract_all_links(str(po_dir))
    print(f"Found translations in {len(links_data)} languages", file=sys.stderr)
    
    # Generate symlink commands
    commands = generate_symlink_commands(links_data)
    
    # Output results
    output = '\n'.join(commands)
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"Written {len(commands)} commands to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == '__main__':
    main()
