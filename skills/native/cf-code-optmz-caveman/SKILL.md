---
name: code-optmz-caveman
description: Optimize code for performance, readability, efficiency. Caveman-mode feedback (terse one-line findings). Trigger /code-optmz-caveman or alias /optmz.
---

# code-optmz-caveman

Optimize code for performance, readability, and efficiency. Feedback in caveman mode (compressed, terse).

## Usage

```
/code-optmz-caveman
```

## What it does

- Analyzes current code/changes for optimization opportunities
- Identifies redundancy, inefficiency, bloat
- Suggests concrete fixes (no vague recommendations)
- Delivers feedback in ultra-compressed caveman format
- Preserves technical accuracy while cutting token waste

## Trigger contexts

- Code review stage before PR
- Post-refactor verification
- Performance tuning
- Tech debt cleanup
- Token optimization audits

## Output format

One-line findings pattern:
```
[file:line] [issue]. [fix].
```

Example:
```
auth.ts:42 Loop creates array every iteration. Use Set, reuse across iterations.
db.ts:89 N+1 query — fetch once with LEFT JOIN not loop.
types.ts:5 Unused import OrderType. Delete.
```

## Mode

Always responds in caveman full mode. Auto-resumes normal for security warnings.

## Config

Enabled globally via hook. Alias: `optmz` (shorthand).
