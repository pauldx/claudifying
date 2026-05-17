---
name: cf-tools-web-sitemap-generate
description: "Generate sitemap.xml from a local static site directory by crawling .html files. Trigger: /cf-tools-web-sitemap-generate"
trigger: /cf-tools-web-sitemap-generate
version: 1.0.0
---

# /cf-tools-web-sitemap-generate

Walk a static-site build directory and emit a `sitemap.xml` listing every HTML
page. Uses each file's mtime for `<lastmod>`. Pure Python — no install needed.

## Usage

```
/cf-tools-web-sitemap-generate ./public https://example.com
/cf-tools-web-sitemap-generate ./dist  https://example.com  --priority 0.8
/cf-tools-web-sitemap-generate ./out   https://example.com  --changefreq weekly
```

Arguments:
1. `site-dir` (required) — root of the built static site
2. `base-url` (required) — public origin, e.g. `https://example.com` (no trailing `/`)
3. `--priority N` (optional, default `0.5`) — uniform priority for all URLs
4. `--changefreq <freq>` (optional, default `monthly`) — always|hourly|daily|weekly|monthly|yearly|never

## What You Must Do When Invoked

### Step 1 — Validate args

```bash
DIR="$1"
BASE="$2"
[ -d "$DIR" ]  || { echo "ERROR: not a directory: $DIR"; exit 1; }
case "$BASE" in
  http://*|https://*) BASE="${BASE%/}" ;;
  *) echo "ERROR: base-url must include scheme (http(s)://)"; exit 1 ;;
esac
```

### Step 2 — Run generator

```bash
python3 - "$DIR" "$BASE" "$@" <<'PY'
import os, sys, datetime
from xml.sax.saxutils import escape

site_dir, base = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
priority   = "0.5"
changefreq = "monthly"
for i, a in enumerate(args):
    if a == "--priority"   and i + 1 < len(args): priority   = args[i+1]
    if a == "--changefreq" and i + 1 < len(args): changefreq = args[i+1]

urls = []
for root, _, files in os.walk(site_dir):
    for f in files:
        if not f.endswith(".html"):
            continue
        full = os.path.join(root, f)
        rel  = os.path.relpath(full, site_dir).replace(os.sep, "/")
        # index.html → directory URL
        if rel.endswith("index.html"):
            rel = rel[:-len("index.html")]
        loc = f"{base}/{rel}".rstrip("/")
        if not loc.endswith("/") and "." not in os.path.basename(loc):
            loc = loc  # keep as page URL
        mtime = datetime.datetime.fromtimestamp(
            os.path.getmtime(full), tz=datetime.timezone.utc
        )
        urls.append((loc, mtime.strftime("%Y-%m-%d")))

urls.sort()
out = os.path.join(site_dir, "sitemap.xml")
with open(out, "w") as fh:
    fh.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    fh.write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
    for loc, lastmod in urls:
        fh.write("  <url>\n")
        fh.write(f"    <loc>{escape(loc)}</loc>\n")
        fh.write(f"    <lastmod>{lastmod}</lastmod>\n")
        fh.write(f"    <changefreq>{changefreq}</changefreq>\n")
        fh.write(f"    <priority>{priority}</priority>\n")
        fh.write("  </url>\n")
    fh.write("</urlset>\n")

print(f"✅ {len(urls)} URLs → {out}")
PY
```

## Output Contract

```
## Sitemap generated

**Site dir:**   <path>
**Base URL:**   <url>
**Output:**     <site-dir>/sitemap.xml
**Pages:**      <count>
**Priority:**   <N>
**Changefreq:** <freq>
```

If `<count>` is 0, warn the user that no `.html` files were found and verify
they pointed at the correct build output directory.

## Gotchas

- **`index.html` → directory URL** — `/foo/index.html` becomes `/foo/`, not
  `/foo/index.html`. Most static-site routers expect this.
- **Other HTML files keep their extension** — `/foo/bar.html` stays as
  `/foo/bar.html`. Override by post-editing or by using "ugly URLs".
- **`<loc>` URLs are not URL-encoded beyond XML escaping** — file paths with
  spaces will fail validation. Rename files to use hyphens before building.
- **`<lastmod>` uses file mtime, not git commit date** — a `git clone` resets
  mtimes to clone time. Run the generator after build, not after clone.
- **No automatic `priority` heuristics** — the script uses a uniform value.
  Search engines mostly ignore priority anyway.
- **Drafts and unpublished pages get included if they're in the build output** —
  exclude them at the static-site generator level (Hugo `draft: true`, etc.).
- **Result is unminified XML** — that's intentional for diffability. Sitemap
  size limit is 50MB / 50,000 URLs; for larger sites use a sitemap index.

## Cross-Platform Notes

Python 3 ships with macOS and Linux; Windows users may need
`py -3` instead of `python3`. The script is stdlib-only — no pip install
required.
