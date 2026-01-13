#!/usr/bin/env python3
"""
Sort brands.txt file while preserving the structure of each brand entry.
Each entry consists of:
- Optional parent comment lines starting with #< (e.g., #< xx:Unilever)
- A line starting with "xx:" containing the brand name
- Optional metadata lines (wikidata:en:, web:en:, description:en:, etc.)
- A blank line separating entries

Usage:
    sort_brands.py <path_to_brands.txt>

This script sorts the brands according to LANG='C.UTF-8' sort -bf
(case-insensitive, fold-style sorting) to match the brands_sort_test
validation in the Makefile.
"""

import sys
import subprocess
from typing import List, Tuple


def parse_brands_file(filepath: str) -> Tuple[List[str], List[List[str]]]:
    """
    Parse the brands file and return the header and list of brand entries.
    
    Returns:
        Tuple of (header_lines, brand_entries)
        where brand_entries is a list of entry_lines for each brand
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find where the header ends (last comment or blank line before first brand)
    header_end = 0
    for i, line in enumerate(lines):
        if line.startswith('xx:'):
            # Found first brand, go back to find where header ends
            for j in range(i - 1, -1, -1):
                if lines[j].strip() == '' or lines[j].startswith('#'):
                    header_end = j + 1
                    break
            break
    
    header = lines[:header_end]
    body_lines = lines[header_end:]
    
    # Parse brand entries
    brand_entries = []
    current_entry = []
    in_entry = False
    pending_parent_comment = []
    
    for line in body_lines:
        # Handle blank lines first - they separate entries
        if line.strip() == '':
            if in_entry:
                # End of a brand entry
                current_entry.append(line)
                brand_entries.append(current_entry)
                current_entry = []
                in_entry = False
            # Blank line before any brand entry, skip it
        elif line.startswith('xx:'):
            # Start of a new brand entry
            in_entry = True
            # Include any pending parent comment lines
            current_entry = pending_parent_comment + [line]
            pending_parent_comment = []
        elif line.startswith('#<'):
            # Parent comment line - save it for the next brand entry
            pending_parent_comment.append(line)
        elif in_entry:
            # Metadata line for current brand entry
            current_entry.append(line)
        # else: Line before any brand entry started - skip it
        #       (e.g., stray lines in the body that aren't part of any entry)
    
    # Handle case where last entry doesn't end with blank line
    if current_entry and in_entry:
        brand_entries.append(current_entry)
    
    return header, brand_entries


def sort_brands(brand_entries: List[List[str]]) -> List[List[str]]:
    """
    Sort brand entries using the same method as the test: LANG='C.UTF-8' sort -bf
    """
    # Extract xx: lines for sorting
    xx_lines_and_entries = []
    for entry_lines in brand_entries:
        for line in entry_lines:
            if line.startswith('xx:'):
                xx_lines_and_entries.append((line.rstrip('\n'), entry_lines))
                break
    
    # Sort using external sort command
    result = subprocess.run(
        ['sort', '-bf'],
        input='\n'.join(xx for xx, _ in xx_lines_and_entries),
        capture_output=True,
        text=True,
        env={'LANG': 'C.UTF-8'}
    )
    
    if result.returncode != 0:
        print(f"Error running sort: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    sorted_xx_lines = result.stdout.strip().split('\n')
    
    # Map xx: line to entry
    xx_map = {xx: entry for xx, entry in xx_lines_and_entries}
    
    # Return sorted entries
    return [xx_map[xx_line] for xx_line in sorted_xx_lines if xx_line in xx_map]


def write_brands_file(filepath: str, header: List[str], brand_entries: List[List[str]]):
    """
    Write the sorted brands back to the file.
    """
    with open(filepath, 'w', encoding='utf-8') as f:
        # Write header
        f.writelines(header)
        
        # Write sorted brand entries
        for entry_lines in brand_entries:
            f.writelines(entry_lines)


def main():
    if len(sys.argv) != 2:
        print("Usage: sort_brands.py <brands.txt>", file=sys.stderr)
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    # Parse the file
    header, brand_entries = parse_brands_file(filepath)
    
    print(f"Found {len(brand_entries)} brand entries")
    
    # Sort the entries
    sorted_entries = sort_brands(brand_entries)
    
    # Write back
    write_brands_file(filepath, header, sorted_entries)
    
    print(f"Sorted {len(sorted_entries)} brand entries")


if __name__ == '__main__':
    main()
