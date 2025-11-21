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


def parse_brands_file(filepath: str) -> Tuple[List[str], List[Tuple[str, List[str]]]]:
    """
    Parse the brands file and return the header and list of brand entries.
    
    Returns:
        Tuple of (header_lines, brand_entries)
        where brand_entries is a list of (sort_key, entry_lines)
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
    sort_key = None
    pending_parent_comment = []
    
    for line in body_lines:
        if line.startswith('#<'):
            # Parent comment line - save it for the next brand entry
            pending_parent_comment.append(line)
        elif line.startswith('xx:'):
            # Extract the brand name for sorting
            # Remove "xx: " prefix and get first brand name (before comma)
            brand_text = line[4:].strip()
            # Get the first brand name (before comma if multiple)
            first_brand = brand_text.split(',')[0].strip()
            sort_key = first_brand
            # Include any pending parent comment lines
            current_entry = pending_parent_comment + [line]
            pending_parent_comment = []
        elif sort_key is not None:
            current_entry.append(line)
            # Check if this is the end of the entry (blank line)
            if line.strip() == '':
                brand_entries.append((sort_key, current_entry))
                current_entry = []
                sort_key = None
    
    # Handle case where last entry doesn't end with blank line
    if current_entry and sort_key is not None:
        brand_entries.append((sort_key, current_entry))
    
    return header, brand_entries


def sort_brands(brand_entries: List[Tuple[str, List[str]]]) -> List[Tuple[str, List[str]]]:
    """
    Sort brand entries using the same method as the test: LANG='C.UTF-8' sort -bf
    """
    # Create a mapping from xx: line to entry and collect all xx: lines
    entry_map = {}
    xx_lines = []
    for key, entry_lines in brand_entries:
        # Find the actual xx: line from the entry
        xx_line = None
        for line in entry_lines:
            if line.startswith('xx:'):
                xx_line = line.rstrip('\n')
                break
        if xx_line:
            entry_map[xx_line] = (key, entry_lines)
            xx_lines.append(xx_line + '\n')
    
    # Use external sort command to match the test's behavior
    result = subprocess.run(
        ['sort', '-bf'],
        input=''.join(xx_lines),
        capture_output=True,
        text=True,
        env={'LANG': 'C.UTF-8'}
    )
    
    if result.returncode != 0:
        print(f"Error running sort: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    sorted_xx_lines = result.stdout.strip().split('\n')
    
    # Build sorted list based on the sorted xx: lines
    sorted_entries = []
    for sorted_line in sorted_xx_lines:
        sorted_line = sorted_line.rstrip('\n')
        if sorted_line in entry_map:
            sorted_entries.append(entry_map[sorted_line])
    
    return sorted_entries


def write_brands_file(filepath: str, header: List[str], brand_entries: List[Tuple[str, List[str]]]):
    """
    Write the sorted brands back to the file.
    """
    with open(filepath, 'w', encoding='utf-8') as f:
        # Write header
        f.writelines(header)
        
        # Write sorted brand entries
        for _, entry_lines in brand_entries:
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
