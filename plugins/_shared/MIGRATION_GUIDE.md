# Analyzer Template Migration Guide

## Overview

**Problem**: 248+ duplicated analyzer functions across plugins (main, analyze_directory, analyze_file, generate_report, generate_recommendations).

**Solution**: Inherit from `AnalyzerBase` in `plugins/_shared/analyzer_base.py`. Reduce 240+ lines of boilerplate to 25-30 lines per plugin.

---

## Before (240+ lines)

```python
#!/usr/bin/env python3
import os, json, argparse
from pathlib import Path
from typing import Dict, List
from datetime import datetime

class Analyzer:
    def __init__(self, target_path: str):
        self.target_path = Path(target_path)
        self.stats = {'total_files': 0, ...}
    
    def analyze_directory(self) -> Dict:
        # 30 lines: recursive file traversal
        
    def analyze_file(self, file_path: Path):
        # 20 lines: file metadata tracking
        
    def generate_recommendations(self):
        # 15 lines: generic recommendations
        
    def generate_report(self) -> str:
        # 40 lines: formatted report generation

def main():
    # 20 lines: CLI parsing + file I/O
    ...
```

---

## After (25-30 lines)

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase

class MyAnalyzer(AnalyzerBase):
    """Domain-specific analyzer."""
    
    def analyze_content(self, file_path: Path) -> None:
        """Your domain logic here."""
        # Parse file, extract metrics, update self.stats
        pass

def main():
    return AnalyzerBase.run_cli(
        MyAnalyzer,
        "Description for CLI help",
        "plugin-name"
    )

if __name__ == "__main__":
    sys.exit(main())
```

---

## Migration Steps

### 1. Identify Plugins Using Generic Pattern

Plugins with `analyze_directory()` and `analyze_file()` methods:

```bash
grep -r "def analyze_directory\|def analyze_file" plugins/ --include="*.py" | cut -d: -f1 | sort -u
```

**Count**: ~20+ plugins (database, devops, security, testing categories).

### 2. For Each Plugin:

#### Step A: Read the Original Script

```bash
cat plugins/CATEGORY/PLUGIN/skills/SKILL/scripts/ANALYZER.py
```

#### Step B: Extract Domain Logic

Identify what the current `analyze_content()` does. Example:
- **database-transaction-monitor**: parses transaction logs, counts rollbacks
- **security/access-control-auditor**: parses config files, finds overpermissions
- **test-coverage-analyzer**: parses coverage reports, extracts metrics

Note any domain-specific methods or attributes (beyond `self.stats`).

#### Step C: Refactor to Inherit from AnalyzerBase

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[5] / '_shared'))
from analyzer_base import AnalyzerBase

class YourAnalyzer(AnalyzerBase):
    def analyze_content(self, file_path: Path) -> None:
        # Your domain logic
        pass

def main():
    return AnalyzerBase.run_cli(
        YourAnalyzer,
        "CLI description",
        "plugin-name"
    )

if __name__ == "__main__":
    sys.exit(main())
```

#### Step D: Test

```bash
python3 plugins/CATEGORY/PLUGIN/skills/SKILL/scripts/ANALYZER.py --help
python3 plugins/CATEGORY/PLUGIN/skills/SKILL/scripts/ANALYZER.py . --json | head -20
```

#### Step E: Commit

```bash
git add plugins/CATEGORY/PLUGIN/...
git commit -m "refactor: use AnalyzerBase for PLUGIN_NAME

Inherit from AnalyzerBase in plugins/_shared/analyzer_base.py.
Reduces boilerplate from 240+ lines to 28 lines.

Domain logic isolated in analyze_content() override.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

## Plugins Already Migrated

**Phase 1 (Database):**
- ✅ database-transaction-monitor
- ✅ database-deadlock-detector
- ✅ database-audit-logger

**Phase 2 (Multi-category):**
- ✅ database/sql-query-optimizer
- ✅ devops/git-commit-smart
- ✅ security/access-control-auditor
- ✅ testing/test-coverage-analyzer

---

## Remaining Plugins to Migrate (~16+)

Database:
- [ ] database-index-advisor
- [ ] (others with analyze_directory pattern)

Devops:
- [ ] (git-commit-smart done)

Security:
- [ ] security-headers-analyzer
- [ ] (others)

Testing:
- [ ] visual-regression-tester
- [ ] mutation-test-runner
- [ ] test-report-generator
- [ ] (others)

---

## AnalyzerBase API

### Constructor

```python
AnalyzerBase(target_path: str, plugin_name: str = "Analyzer")
```

### Methods to Override

```python
def analyze_content(self, file_path: Path) -> None:
    """Domain-specific file analysis. Called for each file.
    Update self.stats['findings'], self.stats['issues'], self.stats['recommendations'].
    """
```

### Methods You Get (No Override Needed)

- `analyze_directory()` — recursively walks target, calls analyze_file() per file
- `analyze_file(file_path)` — metadata tracking + calls analyze_content()
- `generate_recommendations()` — generic suggestions (override to customize)
- `generate_report()` — formatted output
- `create_cli_parser()` — static helper for standard CLI args
- `run_cli()` — static entry point factory

### Standard stats Dictionary

```python
self.stats = {
    'total_files': int,
    'total_size': int,  # bytes
    'file_types': {ext: count, ...},
    'issues': [str, ...],
    'recommendations': [str, ...],
    'findings': {},  # Your domain data
}
```

---

## Pattern Validation

✅ Works across domains: database, devops, security, testing
✅ Reduces 240+ lines to 25-30 lines per plugin
✅ Domain logic isolated in `analyze_content()` hook
✅ Maintains CLI compatibility (same argparse interface)
✅ Preserves JSON output format
✅ Backward compatible (old scripts still work)

---

## Metrics

- **Boilerplate reduced**: 240+ lines → 25 lines (90% reduction per plugin)
- **Duplicated functions eliminated**: 248 → ~0 in migrated plugins
- **Lines of code saved**: 20+ plugins × 215 lines ≈ 4,300 lines
- **Maintenance burden**: 1 base class vs 20+ copies

---

## Questions?

Refer to AnalyzerBase implementation in `plugins/_shared/analyzer_base.py`.

Example implementations: Phase 1 & 2 refactored plugins.
