#!/usr/bin/env python3
"""
Master script to generate OPF categories taxonomy from Google Product Taxonomy.

This script orchestrates the entire process:
1. Fetch Google Product Taxonomy data and translations
2. Fetch Wikidata mappings
3. Extract data from existing OPF categories
4. Generate new categories.txt file

Usage:
    python 00_run_all.py [--skip-fetch]

Options:
    --skip-fetch    Skip fetching data (use existing cached data)
"""

import argparse
import subprocess
import sys
from pathlib import Path


def run_script(script_name: str, description: str) -> bool:
    """Run a Python script and return success status."""
    print(f"\n{'='*60}")
    print(f"{description}")
    print(f"{'='*60}\n")
    
    script_path = Path(__file__).parent / script_name
    
    try:
        result = subprocess.run(
            [sys.executable, str(script_path)],
            check=True,
            capture_output=False
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"\nError running {script_name}: {e}")
        return False


def main():
    """Main function to orchestrate the taxonomy generation."""
    parser = argparse.ArgumentParser(
        description='Generate OPF categories taxonomy from Google Product Taxonomy'
    )
    parser.add_argument(
        '--skip-fetch',
        action='store_true',
        help='Skip fetching data from external sources (use cached data)'
    )
    args = parser.parse_args()
    
    print("="*60)
    print("Google Product Taxonomy to OPF Categories Converter")
    print("="*60)
    
    steps = []
    
    if not args.skip_fetch:
        steps.extend([
            ('01_fetch_google_product_taxonomy.py', 'Step 1: Fetching Google Product Taxonomy'),
            ('02_fetch_wikidata_mappings.py', 'Step 2: Fetching Wikidata mappings'),
            ('03_extract_existing_data.py', 'Step 3: Extracting existing OPF category data'),
        ])
    else:
        print("\nSkipping data fetch steps (using cached data)")
        steps.append(
            ('03_extract_existing_data.py', 'Step 1: Extracting existing OPF category data')
        )
    
    steps.append(
        ('04_generate_opf_taxonomy.py', f'Step {len(steps)+1}: Generating new taxonomy')
    )
    
    # Run all steps
    for script, description in steps:
        success = run_script(script, description)
        if not success:
            print(f"\nFailed at: {description}")
            print("Aborting...")
            return 1
    
    print("\n" + "="*60)
    print("SUCCESS!")
    print("="*60)
    print("\nThe new taxonomy has been generated.")
    print("Check the output file at:")
    print("  scripts/taxonomies/generators/google_product_taxonomy_data/new_categories.txt")
    print("\nTo use this taxonomy:")
    print("  1. Review the generated file")
    print("  2. Copy it to taxonomies/product/categories.txt")
    print("  3. Run taxonomy tests to validate")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
