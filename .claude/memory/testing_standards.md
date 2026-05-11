---
name: Testing and Quality Standards
description: Quality assurance requirements for extensions
type: feedback
---

# Testing and Quality Standards

## Pre-Submission Testing

### Functional Testing
- [ ] Extension works as documented
- [ ] All examples execute successfully
- [ ] Configuration options work
- [ ] Error handling is graceful

### Compatibility Testing
- [ ] Works with latest Claude Code version
- [ ] Compatible with mentioned versions
- [ ] No breaking changes to existing code
- [ ] Dependencies compatible

### Documentation Testing
- [ ] README instructions are accurate
- [ ] Examples are copy-paste ready
- [ ] Installation steps work
- [ ] Configuration is clear

### Security Testing
- [ ] No hardcoded secrets (API keys, passwords)
- [ ] No path traversal vulnerabilities
- [ ] Input validation implemented
- [ ] No shell injection risks

## Quality Checklist

### Code Quality
- [ ] Clean, readable code
- [ ] No debug statements
- [ ] Proper error handling
- [ ] Follows conventions of extension type
- [ ] Comments for non-obvious logic

### Documentation Quality
- [ ] Clear purpose statement
- [ ] Complete usage examples
- [ ] Configuration fully documented
- [ ] Dependencies listed
- [ ] Troubleshooting section

### Dependency Quality
- [ ] All dependencies explicitly listed
- [ ] Versions specified (not wildcard)
- [ ] Licenses disclosed
- [ ] No unnecessary dependencies
- [ ] Compatible versions

### Security Quality
- [ ] No secrets in code or docs
- [ ] Safe default configurations
- [ ] Input validation implemented
- [ ] Secure file handling
- [ ] No privilege escalation

## Testing Requirements by Type

### Skills
- [ ] Can be invoked and completes
- [ ] Returns expected output
- [ ] Handles errors gracefully
- [ ] Works in Claude Code environment

### Plugins
- [ ] Loads without errors
- [ ] All features functional
- [ ] Configuration works
- [ ] Integrates with Claude Code

### Hooks
- [ ] Triggers on correct events
- [ ] Executes without hanging
- [ ] Handles failures gracefully
- [ ] Respects configuration

### Prompts
- [ ] Valid syntax
- [ ] All variables documented
- [ ] Examples work
- [ ] Clear and concise

### Commands
- [ ] Executable and runs
- [ ] All flags/options work
- [ ] Help text is clear
- [ ] Error messages are useful

## Automated Checks

When submitting PR, checks run:
- ✓ File structure validation
- ✓ README presence
- ✓ LICENSE verification
- ✓ Naming conventions
- ✓ Markdown linting

## Performance Standards

- **Skills:** Complete in <30 seconds
- **Hooks:** Execute in <5 seconds
- **Commands:** No unnecessary delays
- **Memory:** Reasonable resource usage

## Documentation Standards

Every extension requires:

1. **README.md** with:
   - Clear description
   - Installation steps
   - Usage examples (2-3 working examples)
   - Configuration (if applicable)
   - Dependencies (with versions and licenses)
   - Troubleshooting section
   - License statement

2. **LICENSE file** (if not MIT)

3. **Working examples** that can be:
   - Copy-pasted
   - Run immediately
   - Produce expected output

## Review Criteria

Maintainers verify:
- ✓ Structure matches guidelines
- ✓ Documentation is complete
- ✓ Code is tested and working
- ✓ License compliance
- ✓ No security issues
- ✓ Quality standards met
- ✓ No duplicates

## Failing Standards

Extensions will be rejected if:
- ❌ No README or incomplete
- ❌ Untested or non-functional
- ❌ License violations
- ❌ Security vulnerabilities
- ❌ Hardcoded secrets
- ❌ Duplicate of existing extension
- ❌ Violates best practices

## Addressing Feedback

If rejected with feedback:
1. Address specific issues
2. Test thoroughly
3. Resubmit PR
4. Maintainer re-reviews

---

**Created:** 2026-05-03
