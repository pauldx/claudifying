---
description: Execute the full test suite and report results
user-invocable: true
argument: [test filter pattern] (optional — runs all tests if omitted)
---

# Run Full Test Suite

Detect the project's test framework, run all tests, and report results clearly.

## Step 1: Detect Test Framework

Check the project for test configuration:

```bash
# Node.js
[ -f package.json ] && cat package.json | grep -E '"(jest|vitest|mocha|ava|tap)"'

# Python
[ -f pytest.ini ] || [ -f setup.cfg ] || [ -f pyproject.toml ] && echo "pytest"

# Go
[ -f go.mod ] && echo "go test"

# Rust
[ -f Cargo.toml ] && echo "cargo test"
```

If multiple frameworks exist, ask the user which to run. If none found, inform the user.

## Step 2: Run Tests

Execute the appropriate test command:

| Framework | Command |
|-----------|---------|
| Jest | `npx jest --verbose $ARGUMENTS` |
| Vitest | `npx vitest run $ARGUMENTS` |
| Mocha | `npx mocha $ARGUMENTS` |
| pytest | `python -m pytest -v $ARGUMENTS` |
| Go | `go test -v ./... $ARGUMENTS` |
| Rust | `cargo test $ARGUMENTS` |

If `$ARGUMENTS` is provided, use it as a filter pattern.

## Step 3: Report Results

Present a clear summary:

```
Test Results
════════════
  Passed:  42
  Failed:  2
  Skipped: 3
  Total:   47
  Duration: 12.3s
```

For each failure, show:
- Test name and file location
- Expected vs actual values
- The relevant source code causing the failure
- A suggested fix if the cause is obvious

## Step 4: Coverage (if available)

If the project has coverage configured, run with coverage:

```bash
# Jest
npx jest --coverage
# pytest
python -m pytest --cov
```

Report coverage percentage and highlight uncovered files.

## Important

- Do NOT modify any code unless the user explicitly asks to fix a failing test
- If tests require a database or external service, inform the user of setup requirements
- If tests take longer than 2 minutes, inform the user of progress
