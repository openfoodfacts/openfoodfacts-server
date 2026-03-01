#!/usr/bin/env python3
"""
GitHub PR Review Comment Generator for Translation Quality Issues

This script generates review comments for translation quality issues that can be
posted on GitHub PRs.

Usage: python3 scripts/generate-translation-pr-comments.py
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path
from typing import List, Dict

# Import the translation checker from the hyphenated filename using importlib
import importlib.util

script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

spec = importlib.util.spec_from_file_location(
    "check_translation_quality",
    script_dir / "check-translation-quality.py",
)
check_translation_quality = importlib.util.module_from_spec(spec)
if spec.loader is None:
    raise ImportError("Could not load check-translation-quality.py module")
spec.loader.exec_module(check_translation_quality)
TranslationQualityChecker = check_translation_quality.TranslationQualityChecker


def get_changed_po_files() -> List[str]:
    """Get list of .po files changed in the current PR"""
    # Determine candidate diff ranges, preferring CI-provided refs when available
    base_ref = os.getenv("GITHUB_BASE_REF")
    head_ref = os.getenv("GITHUB_HEAD_REF") or "HEAD"

    candidate_ranges = []

    # If running in GitHub Actions, use the provided base/head refs first
    if base_ref:
        candidate_ranges.append(f"{base_ref}...{head_ref}")
        candidate_ranges.append(f"origin/{base_ref}...{head_ref}")

    # Fall back to common default branch names and remotes
    candidate_ranges.extend([
        "origin/main...HEAD",
        "origin/master...HEAD",
        "main...HEAD",
        "master...HEAD",
    ])

    # Try each candidate range until one works
    for diff_range in candidate_ranges:
        try:
            result = subprocess.run(
                ['git', 'diff', '--name-only', diff_range],
                capture_output=True,
                text=True,
                check=True
            )
            output = result.stdout.strip()

            # Handle empty output
            if not output:
                return []

            files = output.split('\n')
            # Filter for .po files that exist
            po_files = [f for f in files if f and f.endswith('.po') and os.path.exists(f)]
            return po_files
        except subprocess.CalledProcessError:
            # Try the next candidate range
            continue

    # If we reach here, none of the candidate ranges worked
    print(
        "Error: Could not determine list of changed files; "
        "no valid git diff range found.",
        file=sys.stderr,
    )
    return []


def check_changed_files() -> Dict[str, List]:
    """Check all changed .po files for quality issues"""
    changed_files = get_changed_po_files()
    
    if not changed_files:
        print("No .po files changed in this PR")
        return {}
    
    print(f"Checking {len(changed_files)} changed .po files...")
    
    results = {}
    for file_path in changed_files:
        print(f"  Checking {file_path}...")
        checker = TranslationQualityChecker(file_path)
        issues = checker.check_all()
        if issues:
            results[file_path] = issues
    
    return results


def generate_pr_comment_body(results: Dict[str, List]) -> str:
    """Generate a comment body for the PR"""
    if not results:
        return "✅ No translation quality issues found in changed files!"
    
    total_issues = sum(len(issues) for issues in results.values())
    
    body = f"## 🌐 Translation Quality Review\n\n"
    body += f"Found **{total_issues}** translation quality issues in **{len(results)}** files:\n\n"
    
    for file_path, issues in results.items():
        body += f"### 📄 `{file_path}` ({len(issues)} issues)\n\n"
        
        # Group by issue type
        by_type = {}
        for issue in issues:
            if issue.issue_type not in by_type:
                by_type[issue.issue_type] = []
            by_type[issue.issue_type].append(issue)
        
        for issue_type, type_issues in by_type.items():
            body += f"#### {issue_type.replace('_', ' ').title()} ({len(type_issues)} issues)\n\n"
            
            for issue in type_issues[:5]:  # Limit to first 5 of each type
                body += f"**Line {issue.line_num}:**\n"
                body += f"- **msgid:** `{issue.msgid[:100]}{'...' if len(issue.msgid) > 100 else ''}`\n"
                body += f"- **msgstr:** `{issue.msgstr[:100]}{'...' if len(issue.msgstr) > 100 else ''}`\n"
                body += f"- **Issue:** {issue.details}\n\n"
            
            if len(type_issues) > 5:
                body += f"*...and {len(type_issues) - 5} more {issue_type} issues*\n\n"
        
        body += "\n"
    
    body += "\n---\n\n"
    body += "💡 **How to fix these issues:**\n\n"
    body += "1. **Brand Name Translated**: Keep brand names like 'Open Food Facts', 'Green-Score' untranslated\n"
    body += "2. **Placeholder Mismatch**: Ensure all `%s`, `%d` placeholders are preserved in translations\n"
    body += "3. **HTML Tag Mismatch**: Keep HTML tags like `<a>`, `<strong>` consistent between source and translation\n"
    body += "4. **URL Language Mismatch**: URLs should use the correct language code (e.g., `world-fr.openfoodfacts.org` for French)\n\n"
    body += "Please fix these issues in [Crowdin](https://translate.openfoodfacts.org) to ensure they don't reappear.\n"
    
    return body


def main():
    # Change to repository root
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)
    
    results = check_changed_files()
    
    # Generate comment body
    comment_body = generate_pr_comment_body(results)
    print("\n" + "="*80)
    print("PR Comment Body:")
    print("="*80)
    print(comment_body)
    
    # Write to file for GitHub Actions to use
    output_file = Path(tempfile.gettempdir()) / "translation-pr-comment.md"
    output_file.write_text(comment_body)
    print(f"\nComment written to {output_file}")
    
    # Set GitHub Actions output if running in CI
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            # Use multiline output format
            f.write(f"comment_body<<EOF\n{comment_body}\nEOF\n")
            f.write(f"has_issues={'true' if results else 'false'}\n")
    
    # Exit with non-zero if issues found
    return 1 if results else 0


if __name__ == "__main__":
    sys.exit(main())
