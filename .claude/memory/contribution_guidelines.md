---
name: Contribution Guidelines Summary
description: Key rules and process for contributing extensions
type: feedback
---

# Contribution Guidelines

## Quick Summary

1. **Fork & Branch** — Fork repo, create feature branch
2. **Create Extension** — Use CONTRIBUTING.md as guide
3. **Document** — Include clear README with examples
4. **Disclose Dependencies** — List all deps and licenses
5. **Test** — Verify extension works
6. **Submit PR** — Clear title and description

## Quality Requirements

- ✅ Clear documentation (README)
- ✅ Working examples
- ✅ Compatible with latest Claude Code
- ✅ No hardcoded paths/secrets
- ✅ License compliance
- ✅ Tested locally
- ✅ Follows naming conventions

## License Requirements

**Default:** MIT (same as repo)

**If Different:**
- Include LICENSE file in extension
- Declare in README: `License: [license-name]`
- List all dependencies with licenses

**Compatible:**
- MIT, Apache 2.0, BSD ✅
- ISC, MPL 2.0 ✅
- GPL/AGPL (needs disclosure) ⚠️

**Not Allowed:**
- Proprietary (no license)
- Undeclared dependencies
- Conflicting licenses

## PR Process

1. Clear title: `Add: [extension-name] - [description]`
2. Description of functionality
3. Usage example
4. Dependencies listed
5. Maintainer reviews
6. Merged or feedback given

## Review Criteria

- Structure (matches directory layout)
- Documentation (complete and clear)
- License (compliant and disclosed)
- Quality (tested, no secrets)
- Originality (no duplicates)

---

**Created:** 2026-05-03
**Reference:** [CONTRIBUTING.md](../../CONTRIBUTING.md)
