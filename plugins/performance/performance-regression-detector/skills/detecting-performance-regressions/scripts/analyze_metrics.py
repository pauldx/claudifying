#!/usr/bin/env python3
"""
performance-regression-detector - Analysis Script
Analyzes performance metrics from CI/CD pipeline output, comparing against baselines and thresholds. Returns a JSON object indicating regressions.
"""

import sys
from pathlib import Path

# Add plugins/_shared to path for base class
sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase


class Analyzer(AnalyzerBase):
    """Analyzer for performance-regression-detector."""

    def analyze_content(self, file_path: Path) -> None:
        """Domain-specific file analysis."""
        # Override this method with domain logic
        pass


def main():
    return AnalyzerBase.run_cli(
        Analyzer,
        "Analyzes performance metrics from CI/CD pipeline output, comparing against baselines and thresholds. Returns a JSON object indicating regressions.",
        "performance-regression-detector"
    )


if __name__ == "__main__":
    sys.exit(main())
