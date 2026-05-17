---
name: cf-tools-data-csv-diff
description: "Row-level diff between two CSVs: added, removed, and changed rows by key. Trigger: /cf-tools-data-csv-diff"
trigger: /cf-tools-data-csv-diff
version: 1.0.0
---

# /cf-tools-data-csv-diff

Compare two CSVs and report added, removed, and changed rows. Matches rows by a key column (`--key`). For changed rows, lists exactly which columns differ. Output is human-readable by default, or `--format json` for machine consumption.

## Usage

```
/cf-tools-data-csv-diff old.csv new.csv --key name
/cf-tools-data-csv-diff old.csv new.csv --key id --format json
/cf-tools-data-csv-diff old.csv new.csv --key 0 --output diff.txt
/cf-tools-data-csv-diff a.csv b.csv --key name --ignore city,notes
```

Arguments:
1. `old-csv` (required)
2. `new-csv` (required)
3. `--key NAME|INDEX` (required) — column used to match rows; must be unique within each file
4. `--ignore COL1,COL2` (optional) — columns excluded from change detection
5. `--format text|json` (optional, default `text`)
6. `--output PATH` (optional) — default stdout
7. `--delim ,|;|TAB` (optional, default `,`)

## Why python first

| Tool | Key-based match | Per-column change | Available |
|---|---|---|---|
| Python `csv.DictReader` + dict | ✅ | ✅ | stdlib |
| `diff` | ❌ line-by-line only | ❌ | always |
| `mlr join` | ✅ | ⚠️ awkward | brew |
| `csvkit` (`csvjoin`/`csvgrep`) | ✅ | ⚠️ multi-step | `pip install csvkit` |

Row-level structural diff with per-column change reporting is cleanest in Python. No mlr-first here.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
OLD="$1"; NEW="$2"; shift 2
[ -f "$OLD" ] || { echo "ERROR: not found: $OLD"; exit 1; }
[ -f "$NEW" ] || { echo "ERROR: not found: $NEW"; exit 1; }
[ -n "$KEY" ] || { echo "ERROR: --key required"; exit 1; }
```

### Step 2 — Resolve key by name or index

Read header rows from each file, pick column at index if `KEY` is digits, else use literal name. Verify the resolved name exists in both files.

### Step 3 — Diff via Python

```bash
python3 - "$OLD" "$NEW" "$KEY" "$IGNORE" "$FORMAT" "$DELIM" <<'PY'
import csv, json, sys
old_p, new_p, key, ignore, fmt, delim = sys.argv[1:]
ignore = set(ignore.split(",")) if ignore else set()
delim = "\t" if delim == "TAB" else delim

def load(path):
    with open(path, newline="") as f:
        r = csv.DictReader(f, delimiter=delim)
        if key.isdigit():
            key_name = r.fieldnames[int(key)]
        else:
            key_name = key
        if key_name not in r.fieldnames:
            print(f"ERROR: key column '{key_name}' not in {path}"); sys.exit(1)
        rows = {}
        for row in r:
            k = row[key_name]
            if k in rows:
                print(f"ERROR: duplicate key '{k}' in {path}"); sys.exit(1)
            rows[k] = row
        return rows, r.fieldnames, key_name

old_rows, old_cols, key_name = load(old_p)
new_rows, new_cols, _ = load(new_p)

old_keys = set(old_rows); new_keys = set(new_rows)
added = sorted(new_keys - old_keys)
removed = sorted(old_keys - new_keys)
common = old_keys & new_keys
all_cols = [c for c in (old_cols + [c for c in new_cols if c not in old_cols]) if c not in ignore and c != key_name]

changed = []
for k in sorted(common):
    diffs = {}
    for col in all_cols:
        o = old_rows[k].get(col, "")
        n = new_rows[k].get(col, "")
        if o != n:
            diffs[col] = {"old": o, "new": n}
    if diffs:
        changed.append({"key": k, "diffs": diffs})

if fmt == "json":
    print(json.dumps({
        "key_column": key_name,
        "summary": {"added": len(added), "removed": len(removed), "changed": len(changed)},
        "added":   [new_rows[k] for k in added],
        "removed": [old_rows[k] for k in removed],
        "changed": changed,
    }, indent=2, ensure_ascii=False))
else:
    print(f"## CSV diff (key: {key_name})\n")
    print(f"+ Added:   {len(added)}")
    print(f"- Removed: {len(removed)}")
    print(f"~ Changed: {len(changed)}\n")
    if added:
        print("### Added")
        for k in added: print(f"  + {k}: {new_rows[k]}")
    if removed:
        print("### Removed")
        for k in removed: print(f"  - {k}: {old_rows[k]}")
    if changed:
        print("### Changed")
        for c in changed:
            print(f"  ~ {c['key']}")
            for col, d in c["diffs"].items():
                print(f"      {col}: {d['old']!r} → {d['new']!r}")
PY
```

### Step 4 — Write or print

```bash
# Above script prints to stdout; redirect with shell if --output was set
```

## Output Contract

Text format:
```
## CSV diff (key: name)

+ Added:   1
- Removed: 1
~ Changed: 1

### Added
  + Dave: {'name': 'Dave', 'age': '40', 'city': 'Chicago'}

### Removed
  - Carol: {'name': 'Carol', 'age': '35', 'city': 'LA'}

### Changed
  ~ Bob
      age: '25' → '26'
```

JSON format:
```json
{
  "key_column": "name",
  "summary": {"added": 1, "removed": 1, "changed": 1},
  "added":   [...],
  "removed": [...],
  "changed": [{"key": "Bob", "diffs": {"age": {"old": "25", "new": "26"}}}]
}
```

Report:
```
## CSV diff

**Old:**     old.csv (N rows)
**New:**     new.csv (M rows)
**Key:**     name
**Ignored:** city, notes
**Summary:** + <A> added, - <R> removed, ~ <C> changed
**Output:**  diff.txt (or stdout)
**Method:**  python-stdlib
```

## Gotchas

- **Duplicate keys**: skill errors out — row-by-row matching requires uniqueness. Pre-dedupe or pick a composite key (not supported in v1.0 — concat first).
- **Type comparison**: all values are strings (from CSV). `"5"` and `"5.0"` differ. Normalize types before diffing if needed.
- **Column added in new file**: counts as a per-row change on every common key. Use `--ignore` to suppress.
- **Whitespace differences**: trailing spaces in CSV cells are real characters. Pre-trim if you don't care.
- **Reorder = no change**: row order is irrelevant. Only key-based match matters.
- **Key column itself differing**: impossible by construction — the key is what defines identity.
- **Empty file**: empty new = everything removed, empty old = everything added.

## Cross-Platform Notes

- **All platforms**: Python 3 stdlib only.
- **Excel exports**: Excel may add BOM (`\xEF\xBB\xBF`) at start. Pre-strip with `sed -i '1s/^\xEF\xBB\xBF//' file.csv`.
- **Line endings**: `csv` module handles CRLF/LF transparently when files opened with `newline=""`.
