---
name: cf-obsidian-update
description: When the user asks to update a local Obsidian vault with content from a link (x.com tweet, article, GitHub repo), extract resources, or sync web content into a markdown note — activate this skill for fetching link content and appending structured entries to an Obsidian vault file
---

# Obsidian Vault Updater

Fetch content from a URL (tweet, article, GitHub repo) and append structured entries to a target Obsidian vault note.

## Activation

- "Update my Obsidian vault from this link"
- "Add this repo to my vault note"
- "Parse this tweet and append to `<vault-path>`"
- "/cf-obsidian-update"

## Required Inputs

1. **Source URL** — tweet (x.com), article, or GitHub repo URL
2. **Target vault path** — absolute path to `.md` file inside Obsidian vault (e.g. `/Users/<user>/Documents/NotesRepo/.../note.md`)

If either missing, ask user before proceeding.

## Process

### 1. Identify Source Type

| Pattern | Source Type | Fetch Method |
|---------|-------------|--------------|
| `x.com/*/status/*` or `twitter.com/*/status/*` | Tweet | fxtwitter API |
| `github.com/<owner>/<repo>` (no path) | GitHub repo | `gh api repos/<owner>/<repo>` |
| anything else | Generic web | WebFetch |

### 2. Fetch Content

**Tweet** (x.com):

Direct WebFetch on x.com returns `402` (login wall). Use fxtwitter syndication:

```bash
curl -sL "https://api.fxtwitter.com/<username>/status/<tweet_id>" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tweet',{}).get('text',''))"
```

This returns the full note_tweet text (no truncation). Parse embedded URLs (repo links, articles) from the text.

**GitHub repo** (always use `dangerouslyDisableSandbox: true` — `gh api` hits TLS cert errors in sandbox):

```bash
gh api repos/<owner>/<repo> --jq '{full_name, description, stars: .stargazers_count, forks: .forks_count, lang: .language, license: .license.spdx_id, topics, homepage}'
```

**Generic web** — use WebFetch with a prompt like "Extract repo/resource names, URLs, descriptions, and headers from this page."

### 3. Extract Resources

From fetched content, extract one or more resource entries. Each entry should have:

- **Name** (repo name or resource title)
- **URL** (canonical link)
- **Description** (1–2 lines)
- **Metadata** (stars, forks, language, license — if GitHub)
- **Homepage** (if present)
- **Topics/tags** (if present)

For tweets linking to multiple GitHub repos, enrich each repo via `gh api` (step 2 GitHub repo block) to get authoritative metadata — do NOT rely on the tweet's claimed stats.

### 4. Dedupe Against Target File

```bash
grep -l "<repo-url-or-canonical-id>" "<target-vault-path>" 2>/dev/null
```

If present → update existing entry's metadata (stars/forks shift over time). If absent → append new entry.

### 5. Read Target File

Read the target `.md` file. Preserve:

- YAML frontmatter (tags, captured date, etc.)
- Existing entry structure and numbering convention
- Summary table at the end (if present)

### 5a. Update Frontmatter

- Set `captured` date to today's date (YYYY-MM-DD)
- Add relevant new tags based on content being added (e.g. `ai-coding`, `devops`, `automation`, `open-source`) — merge with existing tags, no duplicates

### 6. Append Entry

Entry template (markdown):

```markdown
## <N>. <Resource Name>

<One-line description — capture the hook or value prop.>

- **Repo**: <URL>
- **Homepage**: <homepage URL, omit line if none>
- **Stars**: <N,NNN> · **Forks**: <N,NNN>
- **Lang**: <language> · **License**: <SPDX id>
- **Topics**: <comma-separated, omit line if none>
- **Description**: <official description from gh api>
```

Increment the numbered list. If a summary table exists at the bottom, append a row matching its column schema.

### 7. Update Header Count

If the top header says `# ... — N GitHub Repos ...`, update N to match new total.

### 8. Report

Summarize to user:
- Source URL parsed
- Number of new entries added
- Number of entries updated (if any)
- Target file path
- Any duplicates skipped

**No source attribution in vault files.** Do NOT append source blocks, tweet references, author quotes, or "Source:" paragraphs to vault documents. Keep entries clean — provenance stays in conversation, not in the file.

## Gotchas

- **x.com requires fxtwitter**: Direct WebFetch on x.com returns 402. Twitter syndication (`cdn.syndication.twimg.com`) truncates long tweets and omits `note_tweet` body. Use `api.fxtwitter.com` for full text.
- **Tweet ID extraction**: URL pattern `x.com/<user>/status/<id>?s=XX` — strip query params before calling fxtwitter.
- **GitHub metadata is authoritative**: Tweets may show stale star counts. Always re-fetch via `gh api`.
- **License field**: `gh api` returns `NOASSERTION` when repo has no recognized LICENSE file. Preserve verbatim, don't substitute "None".
- **File vs folder path collision**: Obsidian allows `Foo.md` file and `Foo/` folder to coexist. Before writing, `ls -la` the parent to confirm target is a file, not a folder.
- **PostToolUse formatters**: Some vaults have linters that rewrite markdown on save. After an `Edit`, re-Read before the next Edit if a formatter is suspected.
- **Dedupe key**: Match on repo URL (e.g. `github.com/owner/repo`), not name — names collide across forks.
- **Summary table sync**: If the file has a trailing summary table, every new entry needs a matching row. Missing rows break visual consistency.
- **Numbering**: Re-number entries sequentially after inserts. Don't skip numbers — breaks the mental index.
- **Atomic updates**: When updating the header count, entry list, and summary table, do all three in the same session — partial updates leave the file inconsistent.
- **`gh api` TLS in sandbox**: `gh api` fails with `x509: OSStatus -26276` inside sandbox. Always use `dangerouslyDisableSandbox: true` for all `gh` CLI commands.
- **No source attribution**: Never add "Source:", "Author's closing:", tweet references, or provenance blocks to vault files. Entries only.

## Future Extensions

- **Multiple target files**: route to different notes based on content type (repos → one note, articles → another)
- **Auto-categorization**: infer section/heading from repo topics
- **Scheduled refresh**: re-fetch metadata for all entries in a note to keep stars/forks current
- **Non-GitHub resources**: support NPM, PyPI, HuggingFace pages with equivalent metadata APIs
