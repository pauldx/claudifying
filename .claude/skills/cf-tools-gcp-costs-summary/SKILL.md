---
name: cf-tools-gcp-costs-summary
description: "Monthly GCP spend summary from BigQuery billing export by service/project. Documents setup if export not configured. Trigger: /cf-tools-gcp-costs-summary"
trigger: /cf-tools-gcp-costs-summary
version: 1.0.0
---

# /cf-tools-gcp-costs-summary

GCP has no equivalent of AWS Cost Explorer's free API. Cost data must first be exported from Cloud Billing into BigQuery. This skill queries that export. If the export is not configured, the skill prints the one-time setup instructions instead of failing.

## Usage

```
/cf-tools-gcp-costs-summary                         # last 30 days, group by service
/cf-tools-gcp-costs-summary --days=7
/cf-tools-gcp-costs-summary --month=2026-04
/cf-tools-gcp-costs-summary --group-by=project      # group by project_id
/cf-tools-gcp-costs-summary --group-by=sku          # finer SKU breakdown
/cf-tools-gcp-costs-summary --dataset my-billing-export.gcp_billing
```

Arguments:
1. `--days=<N>` (default 30)
2. `--month=YYYY-MM` — calendar month override
3. `--group-by=service|project|sku|location` (default `service`)
4. `--dataset <project.dataset>` — explicit BigQuery dataset holding the export
5. `--billing-account <id>` — filter to one billing account if multiple are exported

## Prerequisites

### One-time export setup

If the user has not configured the billing export:

1. **Console path:** https://console.cloud.google.com/billing → Billing export → BigQuery export → Edit settings.
2. Create / pick a BigQuery dataset (recommend `<analytics-project>.gcp_billing`).
3. Enable "Standard usage cost" (table `gcp_billing_export_v1_<billing_account_id>`) and optionally "Detailed" or "Pricing".
4. Wait 24h for first data to land. Backfill is not automatic — only forward-looking.

Reference: https://cloud.google.com/billing/docs/how-to/export-data-bigquery-setup

### Required permissions

- `roles/bigquery.dataViewer` on the dataset
- `roles/bigquery.jobUser` on the project where the query runs
- `bq` CLI installed (ships with gcloud SDK)

## What You Must Do When Invoked

### Step 1 — Verify CLI + auth

```bash
command -v bq >/dev/null 2>&1 || {
  echo "ERROR: bq not installed. Install gcloud SDK: brew install --cask google-cloud-sdk"
  exit 1
}
gcloud auth print-access-token >/dev/null 2>&1 || {
  echo "ERROR: no active credentials. Run: gcloud auth login"
  exit 1
}
PROJECT=$(gcloud config get-value project 2>/dev/null)
```

### Step 2 — Locate billing dataset

If `--dataset` not provided, try to discover:

```bash
# Look for tables matching the export naming pattern
bq ls --format=json "$PROJECT:" 2>/dev/null \
  | jq -r '.[].id' \
  | grep -i billing
```

If nothing matches, print the setup instructions block and exit:

```
GCP billing export not detected in project '<project>'.

To enable (one-time, ~5 min):

  1. Open https://console.cloud.google.com/billing
  2. Select your billing account → Billing export
  3. "BigQuery export" → Edit settings
  4. Pick a project + dataset (e.g. <project>.gcp_billing)
  5. Enable "Standard usage cost"

Data lands within 24 hours of enabling. Re-run this command once the
first day of data is available, or pass --dataset <project.dataset>.
```

### Step 3 — Compute window

```bash
if [ -n "$MONTH" ]; then
  START="${MONTH}-01"
  END=$(date -u -d "$START +1 month" +"%Y-%m-%d" 2>/dev/null \
        || date -u -j -v1d -v+1m -f "%Y-%m-%d" "$START" +"%Y-%m-%d")
else
  DAYS="${DAYS:-30}"
  END=$(date -u +"%Y-%m-%d")
  START=$(date -u -d "$END -$DAYS days" +"%Y-%m-%d" 2>/dev/null \
          || date -u -v-"${DAYS}"d +"%Y-%m-%d")
fi
```

### Step 4 — Build the SQL

Group-by columns:
- `service` → `service.description`
- `project` → `project.id`
- `sku` → `sku.description`
- `location` → `location.location`

```sql
SELECT
  service.description AS service,
  ROUND(SUM(cost) + SUM(IFNULL((SELECT SUM(amount) FROM UNNEST(credits)), 0)), 2) AS net_cost,
  ROUND(SUM(cost), 2) AS gross_cost,
  ROUND(SUM(IFNULL((SELECT SUM(amount) FROM UNNEST(credits)), 0)), 2) AS credits,
  currency
FROM `<dataset>.gcp_billing_export_v1_*`
WHERE _PARTITIONTIME >= TIMESTAMP("@start")
  AND _PARTITIONTIME <  TIMESTAMP("@end")
  -- AND billing_account_id = "<id>"   -- optional filter
GROUP BY service, currency
ORDER BY net_cost DESC
LIMIT 25;
```

Run via:
```bash
bq query --use_legacy_sql=false --format=json \
  --parameter="start::$START" --parameter="end::$END" \
  "$SQL"
```

### Step 5 — Render

```
## GCP spend summary

**Window:**     2026-04-16 → 2026-05-16  (30 days)
**Project:**    <project>
**Dataset:**    <billing-dataset>
**Group by:**   SERVICE
**Currency:**   USD

SERVICE                              NET COST     CREDITS    GROSS       %
Compute Engine                       $412.18      -$12.40    $424.58    38.2%
Cloud Storage                        $187.44       $0.00     $187.44    17.3%
Cloud Run                            $ 92.10       $0.00     $ 92.10     8.5%
BigQuery                             $ 71.05      -$ 5.00    $ 76.05     6.6%
Networking                           $ 64.99       $0.00     $ 64.99     6.0%
... (Other)                          $258.17       $0.00     $258.17    19.5%
─────────────────────────────────────────────────────────────────────────
TOTAL                                $1,085.93                          100.0%
```

## Sample Row Shape (BigQuery export)

```json
{
  "billing_account_id": "01ABCD-EFGH12-IJKL34",
  "service": {"id": "6F81-5844-456A", "description": "Compute Engine"},
  "sku": {"id": "0D56-..-..", "description": "N1 Predefined Instance Core running in Americas"},
  "usage_start_time": "2026-05-15T00:00:00Z",
  "project": {"id": "my-prod", "name": "Production"},
  "labels": [...],
  "cost": 4.21,
  "currency": "USD",
  "credits": [{"name": "Sustained Use Discount", "amount": -0.42}],
  "location": {"location": "us-central1", "country": "US", "region": "us"}
}
```

## Output Contract

```
## GCP spend summary

**Window:**    <start> → <end>
**Dataset:**   <dataset>
**Group by:**  <dimension>
**Currency:**  <currency>

<sorted table with net / credits / gross columns>

TOTAL: $<sum> (net)
```

## Gotchas

- **Export lag**: rows land 24–48h after the usage occurred. Today's data is usually empty. Mention this in output.
- **Multiple billing accounts**: a single dataset can hold exports from many accounts. Filter via `billing_account_id` if user has more than one.
- **Detailed vs standard export**: this skill uses the **standard** table `gcp_billing_export_v1_<account>`. Detailed export adds resource-level fields but the schema differs — re-point with `--dataset` and adjust the SQL if needed.
- **Partition filter required**: BigQuery enforces `_PARTITIONTIME` filter on the wildcard table; queries without one fail or scan everything. Always include the date predicate.
- **Credits are negative**: `cost` is gross. `credits[].amount` is negative or zero. Net = `cost + SUM(credits)`. The SQL above handles it.
- **bq query cost**: each call scans bytes — cheap on a tidy billing dataset but watch when joining detailed export. Add `--dry_run` first to estimate bytes if dataset is large.
- **Service account auth in CI**: `gcloud auth activate-service-account --key-file=...` before any `bq` call.

## Cross-Platform Notes

- **macOS / Linux**: `bq` shipped with gcloud SDK.
- **Windows**: `bq.cmd`.
- **Cron / CI**: pass `--quiet` to `bq query` to skip the interactive confirmation on first run; the credentials must be already activated.
