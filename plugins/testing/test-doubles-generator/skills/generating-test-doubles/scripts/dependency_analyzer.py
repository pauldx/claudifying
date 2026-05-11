#!/usr/bin/env python3
"""
test-doubles-generator - Analysis Script
Analyzes code dependencies to determine the appropriate test double types.
"""

import sys
from pathlib import Path

# Add plugins/_shared to path for base class
sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase


class Analyzer(AnalyzerBase):
    """Analyzer for test-doubles-generator."""

    def analyze_content(self, file_path: Path) -> None:
        """Domain-specific file analysis."""
        # Override this method with domain logic
        pass


def main():
    return AnalyzerBase.run_cli(
        Analyzer,
        "Analyzes code dependencies to determine the appropriate test double types.",
        "test-doubles-generator"
    )


if __name__ == "__main__":
    sys.exit(main())
