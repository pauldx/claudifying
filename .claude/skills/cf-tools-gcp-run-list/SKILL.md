---
name: cf-tools-gcp-run-list
description: "List Cloud Run services in the active project with URL, region, traffic split, and last revision. Trigger: /cf-tools-gcp-run-list"
trigger: /cf-tools-gcp-run-list
version: 1.0.0
---

# /cf-tools-gcp-run-list

Snapshot of Cloud Run services in the current project — name, region, URL, latest revision, traffic %, last deployment. Covers Cloud Run "services" (gen2). Use `--jobs` for Cloud Run Jobs instead.

## Usage

```
/cf-tools-gcp-run-list                              # all services across all regions
/cf-tools-gcp-run-list --region us-central1         # single region
/cf-tools-gcp-run-list --project my-other-project   # override project
/cf-tools-gcp-run-list --jobs                       # list Cloud Run Jobs (not services)
/cf-tools-gcp-run-list --filter "metadata.name~web-" # name regex filter
```

Arguments:
1. `--region <name>` — limit to one region (faster). Default: all regions.
2. `--project <id>` — override active project.
3. `--jobs` — list Run Jobs instead of Services.
4. `--filter <expr>` — gcloud filter expression (see `gcloud topic filters`).

## Prerequisites

```bash
command -v gcloud >/dev/null 2>&1 || {
  echo "ERROR: gcloud not installed. brew install --cask google-cloud-sdk"
  exit 1
}
gcloud auth print-access-token >/dev/null 2>&1 || {
  echo "ERROR: no active credentials. Run: gcloud auth login"
  exit 1
}
PROJECT=$(gcloud config get-value project 2>/dev/null)
[ -z "$PROJECT" ] && { echo "ERROR: no active project. gcloud config set project <id>"; exit 1; }
```

Required APIs / permissions:
- API `run.googleapis.com` enabled on the project
- IAM role `roles/run.viewer` (or higher)

## What You Must Do When Invoked

### Step 1 — Service list

All regions (default):
```bash
gcloud run services list \
  --platform managed \
  --project "$PROJECT" \
  --format="table(
    metadata.name,
    metadata.namespace:label=PROJECT,
    metadata.labels['cloud.googleapis.com/location']:label=REGION,
    status.url,
    status.latestReadyRevisionName:label=READY_REV,
    status.traffic[0].percent:label=TRAFFIC,
    metadata.creationTimestamp:label=CREATED
  )"
```

Single region:
```bash
gcloud run services list --region "$REGION" --platform managed --project "$PROJECT" --format=...
```

### Step 2 — Jobs mode

```bash
gcloud run jobs list \
  --project "$PROJECT" \
  ${REGION:+--region "$REGION"} \
  --format="table(
    metadata.name,
    metadata.labels['cloud.googleapis.com/location']:label=REGION,
    status.latestCreatedExecution.name:label=LAST_EXEC,
    status.conditions[0].status:label=READY,
    metadata.creationTimestamp:label=CREATED
  )"
```

### Step 3 — Traffic split detail (optional)

If user asks for traffic details, switch from `--format=table` to JSON and unfold the `status.traffic[]` array per service:
```
SERVICE          REVISION                       TRAFFIC%   TAG
api-prod         api-prod-00042-abc             90         -
api-prod         api-prod-00043-def             10         canary
```

### Step 4 — Render

```
## Cloud Run services

**Project:**   <project-id>
**Scope:**     all regions | <region>
**Filter:**    <filter or "-">

NAME            REGION         URL                                  READY_REV              TRAFFIC   CREATED
api-prod        us-central1    https://api-prod-xxxx-uc.a.run.app   api-prod-00043-def     100%      2026-04-12
worker-stage    us-east1       https://worker-stage-yyyy.a.run.app  worker-stage-00012-..  100%      2026-03-30

Totals: 2 services across 2 regions
```

For Jobs:
```
NAME            REGION         LAST_EXEC                      READY  CREATED
nightly-etl     us-central1    nightly-etl-jhsx2              True   2026-02-10
```

## Sample API Response Shape (JSON)

```json
{
  "metadata": {
    "name": "api-prod",
    "namespace": "my-project",
    "creationTimestamp": "2026-04-12T10:11:12Z",
    "labels": {"cloud.googleapis.com/location": "us-central1"}
  },
  "spec": { "template": { ... } },
  "status": {
    "url": "https://api-prod-xxxx-uc.a.run.app",
    "latestReadyRevisionName": "api-prod-00043-def",
    "traffic": [{"revisionName": "api-prod-00043-def", "percent": 100}],
    "conditions": [{"type": "Ready", "status": "True"}]
  }
}
```

## Output Contract

```
## Cloud Run <services|jobs>

**Project:**  <project>
**Region:**   <region or "all">

<table>

Totals: <N> services across <M> regions
```

## Gotchas

- **API not enabled**: returns "PERMISSION_DENIED" or "API has not been used". Suggest:
  ```bash
  gcloud services enable run.googleapis.com --project "$PROJECT"
  ```
- **All-regions listing is slow**: gcloud iterates each location. Set `--region` if the user knows where things live.
- **Anthos / Knative platform**: `--platform managed` is the cloud-managed variant. If user runs on GKE, swap to `--platform gke` or `--platform kubernetes`. Default to `managed`.
- **Traffic split with tags**: a single service can have 50/50 splits across tagged revisions. The simple table shows only the primary; use `--format=json` for full picture.
- **Jobs vs Services**: Jobs are batch runs (no URL). Don't confuse them — `--jobs` toggle is essential.
- **`gcloud run services list` returns nothing**: usually wrong project or missing IAM. Run `gcloud projects list` to confirm project, then `gcloud auth list` for active account.
- **Domain mappings**: `status.url` is the `*.run.app` URL. Custom domains live in `gcloud beta run domain-mappings list`. Mention this only if user asks.

## Cross-Platform Notes

- **macOS / Linux**: identical commands.
- **Windows**: `gcloud.cmd run services list ...`.
- **CI**: authenticate with `gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS` first; `print-access-token` works only after activation.
