---
name: cf-tools-git-tag-version
description: "Semver bump — parses latest tag, increments patch/minor/major, creates annotated tag, optionally pushes. Trigger: /cf-tools-git-tag-version"
trigger: /cf-tools-git-tag-version
version: 1.0.0
---

# /cf-tools-git-tag-version

Bump the project's semantic version, create an annotated tag, and (on opt-in) push tags to the remote. Reads the most recent `v*` semver tag, increments the chosen component, and writes a new annotated tag with a message. Dry-run by default.

## Usage

```
/cf-tools-git-tag-version patch                   # preview v1.2.3 → v1.2.4
/cf-tools-git-tag-version minor                   # preview v1.2.3 → v1.3.0
/cf-tools-git-tag-version major                   # preview v1.2.3 → v2.0.0
/cf-tools-git-tag-version patch --execute         # create the tag
/cf-tools-git-tag-version patch --execute --push  # create AND push to origin
/cf-tools-git-tag-version --set v2.0.0 --execute  # explicit version override
/cf-tools-git-tag-version patch --message "Bugfix release"
/cf-tools-git-tag-version patch --prefix release-  # tag as release-1.2.4 not v1.2.4
/cf-tools-git-tag-version patch --pre alpha       # v1.2.3 → v1.2.4-alpha.1
```

## What You Must Do When Invoked

### Step 1 — Locate the latest semver tag

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }

PREFIX="${PREFIX:-v}"
LATEST=$(git tag --list "${PREFIX}*" --sort=-v:refname | head -1)

if [ -z "$LATEST" ]; then
  echo "No existing ${PREFIX}* tags. Starting from ${PREFIX}0.0.0"
  LATEST="${PREFIX}0.0.0"
fi
echo "Latest tag: $LATEST"
```

The `--sort=-v:refname` flag uses git's built-in semver-aware sort (since 2.0), correctly placing `v1.10.0` after `v1.2.0`. Plain lexical sort would order them wrong.

### Step 2 — Parse the version

```bash
# Strip prefix, keep major.minor.patch + optional pre-release suffix
VERSION="${LATEST#$PREFIX}"
# Match: 1.2.3 or 1.2.3-alpha.4 or 1.2.3-rc.1+build.7
if [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([0-9A-Za-z.-]+))?(\+([0-9A-Za-z.-]+))?$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  PRE="${BASH_REMATCH[5]}"
else
  echo "ERROR: latest tag is not valid semver: $LATEST"; exit 1
fi
echo "Parsed: major=$MAJOR minor=$MINOR patch=$PATCH pre=${PRE:-<none>}"
```

### Step 3 — Compute the next version

```bash
case "$BUMP" in
  patch) PATCH=$((PATCH + 1)); PRE="" ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0; PRE="" ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0; PRE="" ;;
  *)     echo "ERROR: bump must be patch|minor|major (or use --set)"; exit 1 ;;
esac

# Optional pre-release suffix
if [ -n "$PRE_LABEL" ]; then
  # Increment pre-release counter if same label, else start at 1
  if [[ "$PRE" =~ ^${PRE_LABEL}\.([0-9]+)$ ]]; then
    PRE_N=$((${BASH_REMATCH[1]} + 1))
  else
    PRE_N=1
  fi
  PRE="${PRE_LABEL}.${PRE_N}"
fi

NEW="${PREFIX}${MAJOR}.${MINOR}.${PATCH}"
[ -n "$PRE" ] && NEW="${NEW}-${PRE}"

# Or honor --set override
[ -n "$SET_VERSION" ] && NEW="$SET_VERSION"

echo "Next tag:   $NEW"
```

### Step 4 — Refuse if tag exists or working tree dirty

```bash
if git rev-parse --verify "$NEW" >/dev/null 2>&1; then
  echo "ERROR: tag $NEW already exists. Use --set to override or bump again."
  exit 1
fi

if ! git diff-index --quiet HEAD --; then
  echo "⚠️  Working tree is dirty. Commit or stash before tagging."
  [ "$FORCE" != "1" ] && exit 1
fi
```

### Step 5 — Create annotated tag

```bash
if [ "$EXECUTE" != "1" ]; then
  echo ""
  echo "Dry-run. Re-run with --execute to create $NEW."
  exit 0
fi

MSG="${MESSAGE:-Release $NEW}"
git tag -a "$NEW" -m "$MSG"
echo "✅ Created annotated tag: $NEW"
echo "   Message: $MSG"
echo "   At commit: $(git rev-parse --short "$NEW^{commit}")"
```

Always create **annotated** tags (`-a`), never lightweight ones — annotated tags carry author, date, message, and can be GPG-signed (`-s`). Lightweight tags are just refs and lack provenance.

### Step 6 — Optional push

```bash
if [ "$PUSH" = "1" ]; then
  REMOTE="${REMOTE:-origin}"
  echo "Pushing $NEW to $REMOTE..."
  git push "$REMOTE" "$NEW"
  echo "✅ Pushed $NEW to $REMOTE"
fi
```

Use the explicit `git push <remote> <tag>` form. Avoid `git push --tags` — it pushes *all* local tags, which can flood CI and surprise teammates.

### Step 7 — Show changelog snippet

```bash
echo ""
echo "=== Commits since $LATEST ==="
git log --pretty=format:'  - %s (%an)' "${LATEST}..HEAD"
```

Useful for paste-into-release-notes.

## Output Contract

```
## Version Bump

**Current tag:** v1.2.3
**Bump:**        patch | minor | major | pre-release | --set override
**New tag:**     v1.2.4
**Tag type:**    annotated
**Message:**     "Release v1.2.4"
**At commit:**   <abbrev>
**Pushed:**      no | yes (origin)
**Action:**      dry-run | created | created + pushed

### Commits since v1.2.3
  - fix: edge case in token parser (Jane Doe)
  - chore: bump deps (Bob Smith)
```

## Gotchas

- **`--sort=-v:refname` is essential.** Plain `git tag --list | sort` orders `v1.10.0` before `v1.2.0` because string sort treats `1` < `2`. Always use the version-aware sort.
- **Tags are NOT pushed by default.** A `git push` of branches won't push tags — explicit `git push <remote> <tag>` or the dangerous-but-common `--tags` is required. Print this in the output even if `--push` wasn't passed.
- **Annotated vs lightweight:** the `-a -m "..."` combo is mandatory. A lightweight tag (`git tag v1.2.3`) is missing author/date/message and breaks tooling that reads `git describe --long`.
- **Pre-release ordering:** `v1.2.4-alpha.1 < v1.2.4-alpha.2 < v1.2.4 < v1.2.5`. The `--sort=-v:refname` flag handles this since git 2.4.
- **GPG-signed tags:** for release engineering, `-s` instead of `-a` signs the tag. Surface this in output as a follow-up suggestion if `git config user.signingkey` is set.
- **Existing tag with same name:** `git tag -f <name>` overwrites locally but the remote will refuse `git push` unless `--force` is given. Refuse by default — re-using a published version is a release-management red flag.
- **Monorepos with multiple version streams:** custom prefixes (`--prefix package-name-v`) let multiple packages share one repo. Document this in your project's release docs.
- **Detached HEAD tagging:** allowed by git but error-prone. Warn if `git symbolic-ref HEAD` fails.

## Cross-Platform Notes

- All flags used (`--sort=-v:refname`, `-a`, `-m`, `--list <pattern>`) are stable since git 2.4 (2015). macOS, Linux, Windows Git Bash all support them.
- The bash regex parsing in Step 2 requires bash 3.2+ (default everywhere modern). On dash/sh-only environments, fall back to `awk` or `sed`.
- On Windows CMD, the `^{commit}` peel syntax in `git rev-parse` needs escaping — Git Bash and PowerShell pass it through cleanly. Quote the whole ref: `"v1.2.4^{commit}"`.
