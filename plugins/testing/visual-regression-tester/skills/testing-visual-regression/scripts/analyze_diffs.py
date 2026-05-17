#!/usr/bin/env python3
"""
visual-regression-tester - Analysis Script
Analyzes the visual differences and classifies them as intentional or unintended.
"""

import sys
from pathlib import Path

# Add plugins/_shared to path for base class
sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase


class Analyzer(AnalyzerBase):
    """Analyzer for visual-regression-tester."""

    def analyze_content(self, file_path: Path) -> None:
        """Domain-specific file analysis."""
        # Override this method with domain logic
        pass


def main():
    return AnalyzerBase.run_cli(
        Analyzer,
        "Analyzes the visual differences and classifies them as intentional or unintended.",
        "visual-regression-tester"
    )


if __name__ == "__main__":
    sys.exit(main())
