#!/usr/bin/env python3
"""
Base Analyzer class for plugin analysis scripts.
Provides common infrastructure: directory traversal, reporting, CLI handling.
Subclasses override domain-specific logic in analyze_file() and analyze_content().
"""

import json
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
from abc import ABC, abstractmethod


class AnalyzerBase(ABC):
    """Abstract base class for file/directory analysis plugins."""

    def __init__(self, target_path: str, plugin_name: str = "Analyzer"):
        """
        Initialize analyzer.

        Args:
            target_path: Directory or file to analyze
            plugin_name: Name for report header
        """
        self.target_path = Path(target_path)
        self.plugin_name = plugin_name
        self.stats = {
            'total_files': 0,
            'total_size': 0,
            'file_types': {},
            'issues': [],
            'recommendations': [],
            'findings': {},  # Domain-specific findings
        }

    def analyze_directory(self) -> Dict:
        """Recursively analyze target directory."""
        if not self.target_path.exists():
            self.stats['issues'].append(f"Path does not exist: {self.target_path}")
            return self.stats

        if self.target_path.is_file():
            self.analyze_file(self.target_path)
        else:
            for file_path in self.target_path.rglob('*'):
                if file_path.is_file():
                    self.analyze_file(file_path)

        return self.stats

    def analyze_file(self, file_path: Path) -> None:
        """
        Analyze individual file.

        Default: track file metadata. Subclasses override analyze_content() for domain logic.
        """
        self.stats['total_files'] += 1
        size = file_path.stat().st_size
        self.stats['total_size'] += size

        # Track file types
        ext = file_path.suffix.lower()
        if ext:
            self.stats['file_types'][ext] = self.stats['file_types'].get(ext, 0) + 1

        # Generic file checks
        if size > 100 * 1024 * 1024:  # 100MB
            self.stats['issues'].append(f"Large file: {file_path} ({size // 1024 // 1024}MB)")
        if size == 0:
            self.stats['issues'].append(f"Empty file: {file_path}")

        # Domain-specific analysis
        self.analyze_content(file_path)

    @abstractmethod
    def analyze_content(self, file_path: Path) -> None:
        """
        Domain-specific file analysis. Override in subclass.

        Update self.stats['findings'], self.stats['issues'], self.stats['recommendations'].
        """
        pass

    def generate_recommendations(self) -> None:
        """Generate analysis recommendations. Override to customize."""
        if self.stats['total_files'] == 0:
            self.stats['recommendations'].append("No files found - check target path")

        if len(self.stats['file_types']) > 20:
            self.stats['recommendations'].append("Many file types detected - consider organizing")

        if self.stats['total_size'] > 1024 * 1024 * 1024:  # 1GB
            self.stats['recommendations'].append("Large total size - consider archiving old data")

    def generate_report(self) -> str:
        """Generate formatted analysis report."""
        report = []
        report.append("\n" + "=" * 60)
        report.append(f"ANALYSIS REPORT - {self.plugin_name}")
        report.append("=" * 60)
        report.append(f"Target: {self.target_path}")
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")

        # Statistics
        report.append("📊 STATISTICS")
        report.append(f"  Total Files: {self.stats['total_files']:,}")
        report.append(f"  Total Size: {self.stats['total_size'] / 1024 / 1024:.2f} MB")
        report.append(f"  File Types: {len(self.stats['file_types'])}")

        # Top file types
        if self.stats['file_types']:
            report.append("\n📁 TOP FILE TYPES")
            sorted_types = sorted(self.stats['file_types'].items(), key=lambda x: x[1], reverse=True)[:5]
            for ext, count in sorted_types:
                report.append(f"  {ext or 'no extension'}: {count} files")

        # Issues
        if self.stats['issues']:
            report.append(f"\n⚠️  ISSUES ({len(self.stats['issues'])})")
            for issue in self.stats['issues'][:10]:
                report.append(f"  - {issue}")
            if len(self.stats['issues']) > 10:
                report.append(f"  ... and {len(self.stats['issues']) - 10} more")

        # Recommendations
        if self.stats['recommendations']:
            report.append("\n💡 RECOMMENDATIONS")
            for rec in self.stats['recommendations']:
                report.append(f"  - {rec}")

        report.append("")
        return "\n".join(report)

    @staticmethod
    def create_cli_parser(description: str, plugin_name: str = "Analyzer") -> argparse.ArgumentParser:
        """Create standard CLI argument parser for analyzers."""
        parser = argparse.ArgumentParser(description=description)
        parser.add_argument('target', help='Target directory or file to analyze')
        parser.add_argument('--output', '-o', help='Output report file')
        parser.add_argument('--json', action='store_true', help='Output as JSON')
        return parser

    @staticmethod
    def run_cli(analyzer_class, description: str, plugin_name: str = "Analyzer") -> int:
        """
        Standard CLI entry point for analyzer subclasses.

        Args:
            analyzer_class: Subclass of AnalyzerBase
            description: CLI help text
            plugin_name: Plugin name for reports

        Returns:
            Exit code (0 if no issues, 1 otherwise)
        """
        parser = AnalyzerBase.create_cli_parser(description, plugin_name)
        args = parser.parse_args()

        print(f"🔍 Analyzing {args.target}...")
        analyzer = analyzer_class(args.target)
        stats = analyzer.analyze_directory()
        analyzer.generate_recommendations()

        if args.json:
            output = json.dumps(stats, indent=2)
        else:
            output = analyzer.generate_report()

        if args.output:
            Path(args.output).write_text(output)
            print(f"✓ Report saved to {args.output}")
        else:
            print(output)

        return 0 if len(stats['issues']) == 0 else 1
