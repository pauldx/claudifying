---
name: cf-tools-aws-costs-summary
description: "30-day AWS spend summary by service via Cost Explorer. Requires ce:GetCostAndUsage IAM permission. Trigger: /cf-tools-aws-costs-summary"
trigger: /cf-tools-aws-costs-summary
version: 1.0.0
---

# /cf-tools-aws-costs-summary

Pulls a rolling 30-day (or user-supplied window) cost summary from AWS Cost Explorer, grouped by service. Outputs sorted table + totals. Read-only; calls only `ce:GetCostAndUsage`.

## Usage

```
/cf-tools-aws-costs-summary                          # last 30 days, grouped by service
/cf-tools-aws-costs-summary --days=7                 # last 7 days
/cf-tools-aws-costs-summary --month=2026-04          # whole calendar month
/cf-tools-aws-costs-summary --group-by=REGION        # group by region instead of service
/cf-tools-aws-costs-summary --granularity=DAILY      # day-by-day breakdown
/cf-tools-aws-costs-summary --profile prod
```

Arguments:
1. `--days=<N>` (default 30) — window length ending today
2. `--month=YYYY-MM` — override window with a full calendar month
3. `--group-by=SERVICE|REGION|LINKED_ACCOUNT|USAGE_TYPE` (default `SERVICE`)
4. `--granularity=DAILY|MONTHLY` (default `MONTHLY`)
5. `--profile <name>` — pass through to `aws`

## Prerequisites

### IAM permission

The profile must have at least:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ce:GetCostAndUsage", "ce:GetCostForecast"],
    "Resource": "*"
  }]
}
```

Attach as inline policy, or via `arn:aws:iam::aws:policy/job-function/Billing` for broader access.

### Cost Explorer enabled

Cost Explorer must be turned on at the account level (once, free). If not enabled, API returns `DataUnavailableException`.

Setup link: https://console.aws.amazon.com/cost-management/home#/cost-explorer

## What You Must Do When Invoked

### Step 1 — Verify CLI + permission

```bash
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI missing. brew install awscli"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: bad credentials. Run: aws sso login --profile \"\${AWS_PROFILE:-default}\""
  exit 1
}
```

### Step 2 — Compute date window

```bash
if [ -n "$MONTH" ]; then
  START="${MONTH}-01"
  # last day of month + 1 → exclusive end
  END=$(date -u -j -v1d -v+1m -f "%Y-%m-%d" "$START" +"%Y-%m-%d" 2>/dev/null \
        || date -u -d "$START +1 month" +"%Y-%m-%d")
else
  DAYS="${DAYS:-30}"
  END=$(date -u +"%Y-%m-%d")
  START=$(date -u -v-"${DAYS}"d +"%Y-%m-%d" 2>/dev/null \
          || date -u -d "$END -$DAYS days" +"%Y-%m-%d")
fi
```

Cost Explorer end-date is **exclusive**, so today's date is fine for "through yesterday".

### Step 3 — Call Cost Explorer

```bash
aws ce get-cost-and-usage \
  --time-period "Start=$START,End=$END" \
  --granularity "$GRANULARITY" \
  --metrics "UnblendedCost" \
  --group-by "Type=DIMENSION,Key=$GROUP_BY" \
  --output json
```

### Step 4 — Aggregate + sort

For the `MONTHLY` case there will be 1–2 `ResultsByTime` entries. Sum `Groups[].Metrics.UnblendedCost.Amount` per group key, sort desc.

For `DAILY`, render as a tall table: date × group with totals per day at the bottom.

### Step 5 — Render

```
## AWS spend summary

**Window:**       2026-04-16 → 2026-05-16  (30 days)
**Granularity:**  MONTHLY
**Group by:**     SERVICE
**Profile:**      <profile>
**Currency:**     USD

SERVICE                              COST          %
Amazon EC2 - Compute                 $412.18      38.2%
Amazon S3                            $187.44      17.3%
Amazon CloudWatch                    $ 92.10       8.5%
AWS Lambda                           $ 71.05       6.6%
Amazon RDS                           $ 64.99       6.0%
Tax                                  $ 41.83       3.9%
... (group rest as "Other")          $258.17      19.5%
─────────────────────────────────────────────────────
TOTAL                                $1,127.76   100.0%
```

Show top 10 explicitly, collapse remainder into `Other`.

### Step 6 — Optional forecast

If user appends `--forecast`, also call:
```bash
aws ce get-cost-forecast \
  --time-period "Start=$END,End=<end+30d>" \
  --metric "UNBLENDED_COST" \
  --granularity MONTHLY
```
Print `Forecast (next 30d): $<amount> ± $<ci>`.

## Sample API Response Shape

```json
{
  "ResultsByTime": [
    {
      "TimePeriod": {"Start": "2026-04-16", "End": "2026-05-16"},
      "Total": {},
      "Groups": [
        {
          "Keys": ["Amazon Elastic Compute Cloud - Compute"],
          "Metrics": {
            "UnblendedCost": {"Amount": "412.18", "Unit": "USD"}
          }
        }
      ],
      "Estimated": false
    }
  ]
}
```

## Output Contract

```
## AWS spend summary

**Window:**       <start> → <end>
**Group by:**     <dimension>
**Granularity:**  <granularity>
**Profile:**      <profile>
**Currency:**     <unit>

<sorted table>

TOTAL: $<sum>
```

## Gotchas

- **`AccessDeniedException`**: profile lacks `ce:GetCostAndUsage`. Print the IAM policy snippet above.
- **`DataUnavailableException`**: Cost Explorer not yet enabled OR window is in the future. Direct user to the setup link.
- **Costs lag 24h**: today's data is partial. Default end-date = today, but mention partial-day caveat.
- **API charges $0.01 per request**: spamming this skill costs money. Cache results if user re-runs within 5 minutes.
- **Linked accounts**: management account sees all members; member accounts see only themselves. Add `--group-by=LINKED_ACCOUNT` in the management account for per-account breakdown.
- **Tax / credits**: appear as separate line items. Don't filter them out — the total must include them.
- **date(1) flags differ**: macOS uses `-v`, GNU uses `-d`. Snippet above handles both.

## Cross-Platform Notes

- **macOS**: `date -u -v-30d +"%Y-%m-%d"`.
- **Linux**: `date -u -d "30 days ago" +"%Y-%m-%d"`.
- **Windows / WSL**: same as Linux inside WSL; in PowerShell use `(Get-Date).AddDays(-30).ToString("yyyy-MM-dd")`.
