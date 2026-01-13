#!/usr/bin/env python3
"""
GitHub PR Review Comment Generator for Translation Quality Issues

This script generates review comments for translation quality issues that can be
posted on GitHub PRs.

Usage: python3 scripts/generate-translation-pr-comments.py
"""

import os
import sys
import json
import subprocess
import tempfile
from pathlib import Path
from typing import List, Dict

# Add scripts directory to path for imports
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

# Import the translation checker - handle both module import and direct execution
try:
    from check_translation_quality import TranslationQualityChecker
except ImportError:
    # If running as script, load the module directly
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "check_translation_quality", 
        script_dir / "check-translation-quality.py"
    )
    check_translation_quality = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check_translation_quality)
    TranslationQualityChecker = check_translation_quality.TranslationQualityChecker


def get_changed_po_files() -> List[str]:
    """Get list of .po files changed in the current PR"""
    try:
        # Get the list of changed files
        result = subprocess.run(
            ['git', 'diff', '--name-only', 'origin/main...HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        files = result.stdout.strip().split('\n')
        # Filter for .po files
        po_files = [f for f in files if f.endswith('.po') and os.path.exists(f)]
        return po_files
    except subprocess.CalledProcessError:
        print("Error: Could not get list of changed files", file=sys.stderr)
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
