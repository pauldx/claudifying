---
description: Run code review on current diff or staged changes
user-invocable: true
argument: [file or branch to review] (optional — defaults to staged/unstaged changes)
---

# Code Review

Review code changes for correctness, security, maintainability, and performance.

## Step 1: Identify What to Review

Determine the scope based on the argument or context:

- **No argument**: Review all staged + unstaged changes (`git diff` and `git diff --staged`)
- **File path**: Review only that file's changes
- **Branch name**: Review all changes vs main (`git diff main...<branch>`)

```bash
# Get changed files
git diff --name-only
git diff --staged --name-only
```

Read each changed file in full to understand the surrounding context, not just the diff.

## Step 2: Review Checklist

For each changed file, evaluate:

**Correctness**
- Logic errors, edge cases, off-by-one errors
- Null/undefined access, unhandled promises
- Race conditions in async code
- Resource leaks (unclosed connections, file handles)

**Security**
- Input validation at system boundaries
- Injection risks (SQL, XSS, command injection)
- Hardcoded secrets or credentials
- Overly permissive access controls

**Maintainability**
- Clear naming for variables, functions, classes
- Single responsibility — functions doing too many things
- Dead code or unreachable branches
- Missing error handling where failures are possible

**Performance**
- N+1 query patterns
- Unnecessary re-renders or recomputations
- Large allocations in hot paths

## Step 3: Present Findings

Group by severity:

| Severity | Meaning |
|----------|---------|
| **Critical** | Bugs, security issues, data loss risk — must fix |
| **Warning** | Code smells, potential issues — should fix |
| **Suggestion** | Style, readability — nice to have |

For each finding, include:
- File path and line number
- What the issue is and why it matters
- Suggested fix with code snippet

## Step 4: Summary

End with:
- Total findings by severity
- Overall verdict: **Ship it** / **Needs changes** / **Needs discussion**
- Top 1-3 most important items to address first
