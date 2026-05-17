---
name: cf-tools-gcp-gcs-ls
description: "List GCS buckets or objects with human-readable sizes and last-modified via gsutil. Trigger: /cf-tools-gcp-gcs-ls"
trigger: /cf-tools-gcp-gcs-ls
version: 1.0.0
---

# /cf-tools-gcp-gcs-ls

Wrap `gsutil ls -lhd` (or `gcloud storage ls`) for clean Google Cloud Storage listings: human sizes, last-modified, optional recursion, optional sort.

## Usage

```
/cf-tools-gcp-gcs-ls                                    # list all buckets in active project
/cf-tools-gcp-gcs-ls gs://my-bucket                     # top-level
/cf-tools-gcp-gcs-ls gs://my-bucket/logs/               # under prefix
/cf-tools-gcp-gcs-ls gs://my-bucket/ -r                 # recursive
/cf-tools-gcp-gcs-ls gs://my-bucket --sort=size
/cf-tools-gcp-gcs-ls --project=my-other-project
```

Arguments:
1. `gs-uri` (optional) — omit to list all buckets in the active project
2. `-r` / `--recursive`
3. `--sort=name|size|modified` (default `name`)
4. `--project=<id>` — override active project for this call
5. `--max=<N>` — cap rows (default 1000)

## What You Must Do When Invoked

### Step 1 — Verify tool

Prefer `gsutil` (universal, ships with gcloud SDK). Fall back to `gcloud storage` if gsutil missing.

```bash
if command -v gsutil >/dev/null 2>&1; then
  TOOL=gsutil
elif command -v gcloud >/dev/null 2>&1; then
  TOOL="gcloud storage"
else
  echo "ERROR: neither gsutil nor gcloud installed."
  echo "Install: brew install --cask google-cloud-sdk   (macOS)"
  echo "         https://cloud.google.com/sdk/docs/install"
  exit 1
fi

# Auth probe
gcloud auth print-access-token >/dev/null 2>&1 || {
  echo "ERROR: no active gcloud credentials. Run: gcloud auth login"
  exit 1
}
```

### Step 2 — Bucket list mode

```bash
gsutil ls
# or
gcloud storage buckets list --project="${PROJECT:-$(gcloud config get-value project)}" \
  --format="table(name,storage_class,location,time_created)"
```

### Step 3 — Object list mode

`gsutil` flags:
- `-l` — long listing (size, last-mod, key)
- `-h` — human-readable sizes
- `-d` — list directories themselves (not contents), useful for prefix-only browsing
- `-r` — recursive
- `-a` — include all versions (skip unless asked)

```bash
gsutil ls -lh ${RECURSIVE:+-r} "$GS_URI"
```

Equivalent `gcloud storage`:
```bash
gcloud storage ls --long --readable-sizes ${RECURSIVE:+--recursive} "$GS_URI"
```

### Step 4 — Parse + sort

Raw `gsutil ls -lh` output:
```
       1.2 MiB  2026-05-10T14:22:01Z  gs://my-bucket/logs/app/2026-05-10.log
       512 B   2026-05-09T03:01:00Z  gs://my-bucket/logs/app/heartbeat.txt
TOTAL: 2 objects, 1.20 MiB
```

If `--sort` requested, drop the TOTAL line, parse fields, sort, re-append totals.

### Step 5 — Render

```
## GCS listing

**Target:**      gs://<bucket>/<prefix>
**Project:**     <project-id>
**Recursive:**   yes | no
**Sort:**        name | size | modified

SIZE       MODIFIED              KEY
1.2 MiB    2026-05-10T14:22:01Z  gs://my-bucket/logs/app/2026-05-10.log
512 B      2026-05-09T03:01:00Z  gs://my-bucket/logs/app/heartbeat.txt

Totals: <N> objects · <human-size>
```

## Output Contract

```
## GCS listing

**Target:**     gs://<bucket>[/<prefix>]
**Project:**    <project>
**Recursive:**  <bool>

<size-aligned table>

Totals: <N> objects · <size>
```

## Gotchas

- **`gsutil ls gs://bucket` without trailing slash**: lists the bucket itself, not contents. Always append `/` or `/**` for recursive.
- **`-r` on huge prefixes**: paginates internally but is slow and racks up Class A operations. Warn user.
- **Versioned buckets**: `-a` shows generations. Default off.
- **Cross-project listing**: `gs://other-project-bucket` works if IAM allows, regardless of active project. Project arg only filters the *bucket list* mode.
- **`gcloud storage` is the newer tool**: faster, native, recommended by Google. But many environments still only have `gsutil`. Try gsutil first; mention `gcloud storage` if user wants speed.
- **Public buckets**: `gsutil ls -L gs://bucket` shows ACLs. If listing fails on a known-public bucket, IAM uniform-access may block legacy ACL listing.
- **Retry storms**: `gsutil` retries 429/500 silently — if listing hangs, network may be flaky. `--quiet` doesn't suppress retries; `-q` does.

## Cross-Platform Notes

- **macOS / Linux**: `gsutil` ships with the gcloud SDK installer.
- **Windows**: `gsutil.cmd`. Add SDK bin dir to PATH.
- **WSL**: install gcloud inside WSL for cleanest experience; the Windows host install is reachable but token storage gets confusing.
