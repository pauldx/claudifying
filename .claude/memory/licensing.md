---
name: Licensing Structure and Rules
description: MIT license details and extension licensing requirements
type: reference
---

# Licensing

## Repository License: MIT

The Claudifying repository and all included extensions (unless specified) are licensed under the MIT License.

**What this means:**
- ✅ Anyone can use, modify, and distribute
- ✅ Can use in commercial projects
- ✅ Must include copyright notice
- ✅ No liability for authors
- ✅ No warranty provided

## Extension Licensing

### Default: MIT
All extensions inherit MIT license unless explicitly stated otherwise.

### Custom Licenses

If an extension uses a different license:

1. **Include LICENSE file** in extension directory
2. **Declare in README:**
   ```markdown
   ## License
   Apache 2.0 (or your license)
   ```
3. **List dependencies with their licenses:**
   ```markdown
   ## Dependencies
   - package-name (version) — [license]
   - another-package (version) — [license]
   ```

## Compatible Licenses

| License | Status | Notes |
|---------|--------|-------|
| MIT | ✅ | Preferred |
| Apache 2.0 | ✅ | Compatible |
| BSD 2/3-Clause | ✅ | Compatible |
| ISC | ✅ | Compatible |
| MPL 2.0 | ✅ | File-based |
| GPL 2/3 | ⚠️ | Requires disclosure |
| AGPL | ⚠️ | Requires disclosure |
| Proprietary | ❌ | Not allowed |
| Unlicensed | ❌ | Not allowed |

## Dependency Disclosure

**Required:**
- Name and version
- License identifier
- Link to license (optional)

**Example:**
```markdown
## Dependencies
- axios (1.4.0) — MIT
- lodash (4.17.21) — MIT
- moment (2.29.1) — MIT
```

## License Conflicts

**Incompatible combinations:**
- ❌ GPL + proprietary code
- ❌ AGPL + closed-source dependencies
- ❌ No license + MIT code
- ❌ Undeclared dependencies

**Solution:**
Disclose clearly in README. Contributors assume responsibility for license compliance.

## Legal Notes

- MIT doesn't grant patent rights (disclose if needed)
- MIT doesn't protect trademarks
- Contributors agree to MIT license by submitting PR
- No liability for Claudifying maintainers

## Resources

- [MIT License Text](https://opensource.org/licenses/MIT)
- [SPDX License List](https://spdx.org/licenses/)
- [Choose a License](https://choosealicense.com/)

---

**Created:** 2026-05-03
**Last Reviewed:** 2026-05-03
