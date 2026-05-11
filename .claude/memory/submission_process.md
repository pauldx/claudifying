---
name: Extension Submission Process
description: Step-by-step workflow for contributing extensions
type: feedback
---

# Extension Submission Process

## Complete Workflow

### Phase 1: Preparation
```
1. Check existing extensions (avoid duplicates)
2. Choose extension type (plugin/hook/skill/prompt/command)
3. Read CONTRIBUTING.md
4. Review licensing requirements
```

### Phase 2: Development
```
1. Create extension following template
2. Write comprehensive README
3. Create working examples
4. Test thoroughly locally
5. List all dependencies
6. Verify license compliance
```

### Phase 3: Repository Setup
```
1. Fork claudifying repo
2. Clone to local machine
3. Create feature branch: git checkout -b feature/my-extension
4. Add extension to appropriate directory
```

### Phase 4: Documentation
```
Required files:
├── my-extension/
│   ├── README.md (mandatory)
│   │   ├── Overview
│   │   ├── Installation
│   │   ├── Usage (with examples)
│   │   ├── Configuration
│   │   ├── Dependencies
│   │   └── License
│   ├── [source files]
│   └── LICENSE (if not MIT)
```

### Phase 5: Commit
```bash
git add .
git commit -m "Add: extension-name - Brief description

- What it does
- Key features
- Dependencies (list)"
```

### Phase 6: Push & PR
```bash
git push origin feature/my-extension
```

Then on GitHub:
- Title: `Add: extension-name - Description`
- Description:
  - What does it do?
  - How to use it?
  - Dependencies?
  - License?
- Reviewable code

### Phase 7: Review
```
Maintainer checks:
✓ Structure (correct directory)
✓ Documentation (complete)
✓ Examples (working)
✓ License (compliant)
✓ Quality (tested, no issues)
✓ No duplicates
```

### Phase 8: Merge or Feedback
```
Result:
→ Merged to main
→ Feedback requested (address and resubmit)
→ Rejected (doesn't meet criteria)
```

## PR Checklist

Before submitting, verify:

- [ ] README complete with all sections
- [ ] Usage examples work correctly
- [ ] Dependencies listed with versions and licenses
- [ ] Tested with latest Claude Code
- [ ] No hardcoded paths or secrets
- [ ] Follows naming conventions (lowercase-hyphens)
- [ ] LICENSE file included (if not MIT)
- [ ] No duplicates with existing extensions
- [ ] Committed with clear message
- [ ] PR title and description complete

## Common Issues

### Rejected: Duplicate Extension
**Solution:** Check existing extensions first, or improve existing one

### Rejected: Missing Documentation
**Solution:** Add comprehensive README with examples

### Rejected: License Conflict
**Solution:** Disclose dependencies and their licenses

### Rejected: Untested Code
**Solution:** Test locally and provide working examples

## Timeline

- Submission → Initial Review: 1-2 days
- Review → Feedback/Merge: 3-5 days
- Addressing Feedback → Resubmit: 1-2 days

## Support

Questions? 
- Check CONTRIBUTING.md
- Open GitHub Issue
- Discuss in PR comments

---

**Created:** 2026-05-03
