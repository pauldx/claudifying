---
name: cf-tools-aws-ec2-status
description: "List EC2 instances in the current region with state, type, public IP, and Name tag. Trigger: /cf-tools-aws-ec2-status"
trigger: /cf-tools-aws-ec2-status
version: 1.0.0
---

# /cf-tools-aws-ec2-status

Snapshot of EC2 instances in the current region — instance ID, Name tag, state, type, public/private IP, AZ. Read-only. Designed for the common "what's running?" check before SSH / before paying the monthly bill.

## Usage

```
/cf-tools-aws-ec2-status                                # current region, all states
/cf-tools-aws-ec2-status --state=running                # filter by state
/cf-tools-aws-ec2-status --region us-west-2             # override region
/cf-tools-aws-ec2-status --tag Environment=prod         # filter by tag
/cf-tools-aws-ec2-status --all-regions                  # iterate every region (slow)
/cf-tools-aws-ec2-status --profile prod                 # named profile
```

Arguments:
1. `--state=<state>` — `running` | `stopped` | `pending` | `terminated` | `*` (default `*`)
2. `--region <name>` — overrides `AWS_REGION` / profile region
3. `--tag KEY=VAL` — filter by tag (repeatable)
4. `--all-regions` — query every enabled region (warn: ~30 API calls)
5. `--profile <name>` — passes through

## What You Must Do When Invoked

### Step 1 — Verify CLI + identity

```bash
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI missing. brew install awscli"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: invalid credentials. Run: aws sso login --profile \"\${AWS_PROFILE:-default}\""
  exit 1
}
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null)}"
[ -z "$REGION" ] && REGION="us-east-1"
```

### Step 2 — Build filter expression

```bash
FILTERS=()
[ -n "$STATE" ] && [ "$STATE" != "*" ] && FILTERS+=(Name=instance-state-name,Values="$STATE")
# tag filters look like Name=tag:Environment,Values=prod
for KV in "${TAG_FILTERS[@]}"; do
  K="${KV%%=*}"; V="${KV#*=}"
  FILTERS+=("Name=tag:$K,Values=$V")
done
```

### Step 3 — Query EC2

```bash
aws ec2 describe-instances \
  --region "$REGION" \
  ${FILTERS[@]:+--filters "${FILTERS[@]}"} \
  --query 'Reservations[].Instances[].{
    Id:InstanceId,
    Name:Tags[?Key==`Name`]|[0].Value,
    State:State.Name,
    Type:InstanceType,
    Public:PublicIpAddress,
    Private:PrivateIpAddress,
    AZ:Placement.AvailabilityZone,
    Launched:LaunchTime
  }' \
  --output json
```

### Step 4 — Render table

```
ID                   NAME             STATE     TYPE        PUBLIC IP        PRIVATE IP       AZ            LAUNCHED
i-0123456789abcdef0  web-prod-1       running   t3.medium   54.231.10.5      10.0.1.42        us-east-1a    2026-04-01
i-0fedcba9876543210  worker-stage-2   stopped   c5.large    -                10.0.2.11        us-east-1b    2026-03-15
```

Color hint (if terminal supports ANSI): green for `running`, yellow for `pending`/`stopping`, red for `terminated`/`stopped`. Plain text otherwise.

### Step 5 — Summary

```
Region: us-east-1
Total:  6 instances   (running: 4, stopped: 1, terminated: 1)
Cost:   ~$<estimate> / mo  (running only — rough estimate, requires --with-pricing flag)
```

Skip cost estimate unless user asks; it requires Pricing API permissions.

### Step 6 — All-regions mode

```bash
aws ec2 describe-regions --query 'Regions[].RegionName' --output text \
  | tr '\t' '\n' \
  | while read R; do
      echo "=== $R ==="
      aws ec2 describe-instances --region "$R" ...
    done
```

Warn user that this runs N requests and may take 30–60s.

## Required IAM Permissions

```
ec2:DescribeInstances
ec2:DescribeRegions          (only for --all-regions)
sts:GetCallerIdentity        (preflight check)
```

## Output Contract

```
## EC2 status

**Profile:**    <profile>
**Region:**     <region>
**Filters:**    state=<state>, tag:Env=<val>, ...

ID  NAME  STATE  TYPE  PUBLIC IP  PRIVATE IP  AZ  LAUNCHED
...

Totals: <N> instances  (running: <r>, stopped: <s>, terminated: <t>)
```

## Gotchas

- **No Name tag**: instances without `Name` show `-`. Don't crash.
- **Reservations vs Instances**: a single `describe-instances` call returns nested `Reservations[].Instances[]`. Flatten with the JMESPath above.
- **PublicIpAddress is null**: for instances in private subnets — render `-`.
- **Spot / scheduled instances**: `State.Name` covers them too.
- **Region default**: if no region set anywhere, `aws` errors with `You must specify a region`. Default to `us-east-1` and tell the user.
- **Pagination**: `describe-instances` paginates above 1000 instances. Add `--no-paginate` only if user wants speed over completeness.
- **Cost field**: real per-instance cost needs the Pricing API and is rarely worth the IAM grant. Skip unless asked.

## Cross-Platform Notes

- **macOS / Linux**: portable; relies on `aws` + `jq` for any extra parsing.
- **Windows / WSL**: same. Use `--output json` and parse with PowerShell if user prefers.
