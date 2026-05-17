# Contributing to Claudifying

Thanks for contributing! This guide covers how to submit extensions to Claudifying.

## Before You Start

1. Check [Issues](https://github.com/pauldx/claudifying/issues) for existing discussions
2. Follow extension guidelines below
3. Test your extension thoroughly

## How to Contribute

### 1. Fork & Branch
```bash
git clone https://github.com/pauldx/claudifying.git
cd claudifying
git checkout -b feature/my-extension
```

### 2. Create Extension

Use template below and place in appropriate directory:
- `plugins/` — Claude Code plugins
- `hooks/` — Hook scripts
- `skills/` — Skill definitions
- `prompts/` — Prompt templates
- `commands/` — CLI commands

### 3. Document Extension

Include README in extension folder:
```
my-extension/
├── README.md
├── [extension files]
└── LICENSE (if different from MIT)
```

### 4. Submit PR

```bash
git add .
git commit -m "Add: [extension-name] - [brief description]"
git push origin feature/my-extension
```

Open PR with:
- Clear title: `Add: [extension-name]`
- Description of what it does
- Usage example
- Dependencies listed

## Extension Guidelines

### Required
- ✅ Clear documentation (README)
- ✅ Working example/usage
- ✅ License compliance disclosure
- ✅ Descriptive naming (lowercase, hyphens)

### Quality Standards
- Compatible with latest Claude Code
- No hardcoded paths or secrets
- Tested locally before submission
- Follows project structure

### License Requirements

**Default:** MIT (same as repo)

**If different:**
1. Include LICENSE file in extension
2. Declare in README: `License: [license-name]`
3. List all dependencies with their licenses

**Compatible licenses:**
- MIT, Apache 2.0, BSD variants ✅
- ISC, MPL 2.0 ✅
- GPL/AGPL (requires disclosure, separate section) ⚠️

**Not allowed:**
- Proprietary (no license)
- Conflicting licenses
- Undeclared dependencies

### Dependency Disclosure

List in extension README:
```markdown
## Dependencies
- [package-name] ([version]) — [license]
- [package-name] ([version]) — [license]
```

## Review Process

1. Automated checks run (lint, structure)
2. Maintainer reviews for quality/conflicts
3. License compliance verified
4. Merged or feedback provided

## Code of Conduct

- Be respectful
- No spam or self-promotion only
- Follow project values
- Report issues constructively

## Questions?

Open [GitHub Issue](https://github.com/pauldx/claudifying/issues) or discuss in PR.

## License

By contributing, you agree to license your extension under MIT (unless specified otherwise in your extension's LICENSE file).
