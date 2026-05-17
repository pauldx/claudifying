---
name: cf-release-manager
description: When the user asks to prepare a release, create release notes, manage changelogs, tag a version, rollback a deploy, or monitor deployment status — activate this release management skill
---

# Release Manager

End-to-end release lifecycle management: version bumping, changelog generation, tagging, release notes, rollback procedures, and deploy monitoring.

## Activation

- User says "prepare a release", "create release notes", "tag a version", "bump version"
- User needs to rollback a deployment or check deploy status
- User wants automated changelog from commit history

## Capabilities

### Prepare Release

Bump the version following semver conventions:

```bash
# Determine current version
git describe --tags --abbrev=0 2>/dev/null || echo "No tags found"

# Check commits since last tag
git log $(git describe --tags --abbrev=0 2>/dev/null)..HEAD --oneline
```

Version bump rules:
- **patch** (x.x.X): bug fixes, docs, minor improvements
- **minor** (x.X.0): new features, non-breaking enhancements
- **major** (X.0.0): breaking changes, API removals, major refactors

Update version in: `package.json`, `Cargo.toml`, `pyproject.toml`, `version.go`, or whatever the project uses. Create a signed git tag.

### Generate Changelog

Build a changelog from conventional commits since the last tag:

```bash
git log $(git describe --tags --abbrev=0)..HEAD --format="%s (%h)" --no-merges
```

Categorize entries:
- **Features**: commits starting with `feat:`
- **Bug Fixes**: commits starting with `fix:`
- **Breaking Changes**: commits with `BREAKING CHANGE` in body or `!` after type
- **Other**: `docs:`, `refactor:`, `test:`, `chore:`

Output in Keep-a-Changelog format with date and version header.

### Release Notes

Generate release notes from merged PRs for richer context:

```bash
# PRs merged since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
LAST_TAG_DATE=$(git log -1 --format=%aI "$LAST_TAG" 2>/dev/null)
gh pr list --state merged --base main --search "merged:>=$LAST_TAG_DATE" --json number,title,labels,author
```

Format as GitHub release notes with:
- Highlighted breaking changes at the top
- Grouped features and fixes
- Contributor acknowledgments
- Link to full diff between tags

### Rollback

When a deployment goes wrong:

```bash
# Identify last known good tag/commit
git log --oneline --decorate -10

# Option A: Revert the release commits (preserves history)
git revert --no-commit HEAD~3..HEAD
git commit -m "revert: rollback release vX.Y.Z"

# Option B: Deploy previous tag directly
git checkout tags/vX.Y.Z
```

Always prefer revert over reset to preserve history. Verify rollback success by checking CI status.

### Deploy Monitoring

Watch deployment status after release:

```bash
# Check GitHub Actions runs
gh run list --limit 5

# Watch a specific run
gh run watch <run-id>

# Check workflow conclusion
gh run view <run-id> --json conclusion,status
```

## Process

### 1. Assess Release Scope

- List all changes since last tag
- Determine appropriate version bump
- Identify any breaking changes that need migration notes

### 2. Generate Artifacts

- Bump version in project files
- Generate changelog entries
- Create release notes draft

### 3. Tag and Publish

```bash
git tag -a "vX.Y.Z" -m "Release vX.Y.Z"
git push origin "vX.Y.Z"
gh release create "vX.Y.Z" --title "vX.Y.Z" --notes-file RELEASE_NOTES.md
```

### 4. Verify

- Confirm CI passes on the tag
- Check deployment status
- Verify release artifacts are published

## Output

- Version bump summary (old -> new)
- Formatted changelog entries
- Release notes (markdown, ready for GitHub release)
- Post-release verification status

## Gotchas

- **No existing tags**: If the repo has no tags, ask the user for the initial version rather than assuming v0.1.0
- **Monorepo versioning**: Monorepos may need independent versioning per package — detect `workspaces` in package.json and ask which package to release
- **gh release create** fails if the tag does not exist remotely — push the tag before creating the release
- **Conventional commits**: Changelog generation depends on consistent commit message format — warn if commits do not follow conventions
- **Protected branches**: Tag pushes may be blocked by branch protection rules — the user may need admin access
- **Rollback scope**: Reverting a merge commit requires `--mainline 1` flag — omitting it causes git to error with "is a merge but no -m option was given"
- **Version files**: Some projects have version in multiple files (package.json + lock file, pyproject.toml + __init__.py) — update all of them
- **Pre-release versions**: Support `alpha`, `beta`, `rc` suffixes when the user asks for a pre-release (e.g., v2.0.0-rc.1)
- Never auto-push tags or create releases without explicit user confirmation
