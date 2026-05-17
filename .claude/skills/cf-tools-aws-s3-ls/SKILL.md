---
name: cf-tools-aws-s3-ls
description: "List S3 buckets or objects under a prefix with human-readable sizes and last-modified timestamps. Trigger: /cf-tools-aws-s3-ls"
trigger: /cf-tools-aws-s3-ls
version: 1.0.0
---

# /cf-tools-aws-s3-ls

Wrap `aws s3 ls` / `aws s3api list-objects-v2` to produce readable bucket and object listings: human sizes, ISO timestamps, sort by size or modified, optional recursive walk.

## Usage

```
/cf-tools-aws-s3-ls                                   # list all buckets in current account
/cf-tools-aws-s3-ls s3://my-bucket                    # top-level contents
/cf-tools-aws-s3-ls s3://my-bucket/logs/              # contents under prefix
/cf-tools-aws-s3-ls s3://my-bucket/logs/ --recursive  # recurse into all sub-prefixes
/cf-tools-aws-s3-ls s3://my-bucket --sort=size        # sort objects by size desc
/cf-tools-aws-s3-ls --profile prod s3://my-bucket     # use named profile
```

Arguments:
1. `s3-uri` (optional) — if omitted, lists all buckets. Else `s3://bucket[/prefix]`.
2. `--recursive` (optional) — descend into nested prefixes.
3. `--sort=name|size|modified` (optional, default `name`).
4. `--profile <name>` (optional) — passes through to `aws`.
5. `--max=<N>` (optional, default 1000) — cap returned rows.

## What You Must Do When Invoked

### Step 1 — Verify CLI + credentials

```bash
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI missing. brew install awscli"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: AWS credentials invalid or expired."
  echo "Fix: aws sso login --profile \"\${AWS_PROFILE:-default}\""
  exit 1
}
```

### Step 2 — Bucket list mode (no s3-uri)

```bash
aws s3api list-buckets \
  --query 'Buckets[].{Name:Name,Created:CreationDate}' \
  --output table
```

For each bucket, optionally show region (cheap call):
```bash
aws s3api get-bucket-location --bucket "$NAME" --query LocationConstraint --output text
```

Skip the region fetch if there are >50 buckets (rate-limit risk).

### Step 3 — Object list mode

Parse `s3://bucket[/prefix]`:
```bash
BUCKET=$(echo "$S3_URI" | sed -E 's#^s3://##' | cut -d/ -f1)
PREFIX=$(echo "$S3_URI" | sed -E 's#^s3://[^/]+/?##')
```

Non-recursive (top-level only) → use delimiter:
```bash
aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "$PREFIX" \
  --delimiter / \
  --max-items "$MAX" \
  --output json
```

Recursive → omit delimiter; paginate via `--starting-token` if `NextContinuationToken` present.

### Step 4 — Format rows

For each `Contents[]` entry, render:
```
SIZE    MODIFIED              KEY
1.2 MB  2026-05-10T14:22:01Z  logs/app/2026-05-10.log
512 B   2026-05-09T03:01:00Z  logs/app/heartbeat.txt
```

Human size helper (POSIX):
```bash
hsize() {
  awk -v b="$1" 'BEGIN{
    s="BKMGTP"; i=1;
    while(b>=1024 && i<length(s)){ b/=1024; i++ }
    printf "%.1f %s\n", b, substr(s,i,1)
  }' | sed 's/B/B  /; s/\.0 //'
}
```

For prefixes (`CommonPrefixes`) display:
```
DIR     <prefix>/
```

### Step 5 — Sort + totals

After collecting rows, sort by chosen key, then print summary:
```
Total objects: <N>
Total size:    <human>
Prefixes:      <M>
```

## Output Contract

```
## S3 listing

**Target:**     s3://<bucket>/<prefix>
**Profile:**    <profile or "default">
**Region:**     <bucket-region>
**Recursive:**  yes | no
**Sort:**       name | size | modified

SIZE      MODIFIED              KEY
...

Totals: <N> objects · <human-size> · <M> common prefixes
```

## Gotchas

- **Access denied on bucket location**: bucket may be in another account or region; fall back to `aws s3 ls s3://bucket` which doesn't need `GetBucketLocation`.
- **EU-region buckets**: `LocationConstraint` returns `null` for `us-east-1` — treat null as `us-east-1`.
- **Large prefixes**: `list-objects-v2` returns max 1000 per page; honor `NextContinuationToken` or warn user listing was truncated.
- **Versioned buckets**: `list-objects-v2` only shows current versions. Mention `list-object-versions` for full history.
- **Glacier objects**: still appear with full size; restoring is a separate call.
- **`s3 ls --human-readable`**: simpler one-liner if user just wants quick output:
  ```bash
  aws s3 ls s3://my-bucket/prefix/ --human-readable --summarize
  ```
  Use this short form when user has not asked for sorting or recursion.
- **Pagination cost**: each page is one billable LIST. Recursive on million-object buckets is expensive — warn user.

## Cross-Platform Notes

- **macOS / Linux**: identical CLI. Use `awk` for size formatting (portable).
- **Windows / WSL**: use PowerShell's `Format-Table` or just stick to WSL bash.
- **CI**: in CI, set `AWS_PAGER=""` or pipe to `cat` to disable the interactive pager.
