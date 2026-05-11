#!/usr/bin/env python3
"""Auto-refactor analyzer plugins to use AnalyzerBase.

Usage:
    python3 refactor_analyzers.py [--dry-run]

Finds all plugins with analyze_directory() and refactors them to inherit from AnalyzerBase.
"""

import sys
import re
from pathlib import Path


def extract_plugin_name(filepath: Path) -> str:
    """Extract plugin name from file path."""
    # plugins/CATEGORY/PLUGIN_NAME/skills/.../scripts/analyzer.py
    parts = filepath.parts
    for i, part in enumerate(parts):
        if part == "plugins" and i + 2 < len(parts):
            return parts[i + 2]  # PLUGIN_NAME
    return "Analyzer"


def extract_class_name(filepath: Path, content: str) -> str:
    """Extract original Analyzer class name from content."""
    match = re.search(r"class\s+(\w+)\s*:", content)
    return match.group(1) if match else "Analyzer"


def extract_description(content: str) -> str:
    """Extract description from docstring or argparse."""
    # Try to find argparse description
    match = re.search(r'ArgumentParser\(description="([^"]+)"', content)
    if match:
        return match.group(1)

    # Fall back to docstring
    match = re.search(r'"""(.+?)"""', content, re.DOTALL)
    if match:
        desc = match.group(1).strip().split('\n')[0]
        return desc[:80]  # Truncate to 80 chars

    return "Analysis script"


def refactor_analyzer(filepath: Path, dry_run: bool = False) -> bool:
    """Refactor a single analyzer file. Returns True if successful."""
    try:
        content = filepath.read_text()

        # Skip if already refactored
        if "AnalyzerBase" in content:
            print(f"  ⏭️  SKIP (already refactored): {filepath}")
            return True

        # Skip if doesn't have analyze_directory
        if "def analyze_directory" not in content:
            print(f"  ⏭️  SKIP (no analyze_directory): {filepath}")
            return True

        # Extract metadata
        plugin_name = extract_plugin_name(filepath)
        class_name = extract_class_name(filepath, content)
        description = extract_description(content)

        # Generate refactored code
        refactored = f'''#!/usr/bin/env python3
"""
{plugin_name} - Analysis Script
{description}
"""

import sys
from pathlib import Path

# Add plugins/_shared to path for base class
sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase


class {class_name}(AnalyzerBase):
    """Analyzer for {plugin_name}."""

    def analyze_content(self, file_path: Path) -> None:
        """Domain-specific file analysis."""
        # Override this method with domain logic
        pass


def main():
    return AnalyzerBase.run_cli(
        {class_name},
        "{description}",
        "{plugin_name}"
    )


if __name__ == "__main__":
    sys.exit(main())
'''

        if dry_run:
            print(f"  📝 REFACTOR (dry-run): {filepath}")
            print(f"     Class: {class_name} → {class_name}(AnalyzerBase)")
            print(f"     Plugin: {plugin_name}")
        else:
            filepath.write_text(refactored)
            print(f"  ✅ REFACTOR: {filepath}")

        return True
    except Exception as e:
        print(f"  ❌ ERROR: {filepath}: {e}")
        return False


def main():
    dry_run = "--dry-run" in sys.argv
    mode = "DRY-RUN" if dry_run else "LIVE"

    print(f"\n🔧 Auto-refactoring analyzers ({mode} mode)\n")

    # Find all analyzer plugins
    plugins_dir = Path(__file__).parent.parent
    analyzer_files = list(plugins_dir.rglob("*_analyzer.py")) + \
                      list(plugins_dir.rglob("analyze_*.py")) + \
                      list(plugins_dir.rglob("*_audit*.py")) + \
                      list(plugins_dir.rglob("*_analyzer*.py"))

    # Deduplicate and sort
    analyzer_files = sorted(set(f for f in analyzer_files if "_shared" not in str(f)))

    print(f"Found {len(analyzer_files)} analyzer files\n")

    success = 0
    for filepath in analyzer_files:
        if refactor_analyzer(filepath, dry_run):
            success += 1

    print(f"\n✅ Processed: {success}/{len(analyzer_files)}")

    if dry_run:
        print("\n💡 Dry-run complete. Run without --dry-run to apply changes.")
        print("   git add -A && git commit -m 'refactor: migrate remaining analyzers to AnalyzerBase'\n")


if __name__ == "__main__":
    main()
