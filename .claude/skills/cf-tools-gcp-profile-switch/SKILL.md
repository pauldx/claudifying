---
name: cf-tools-gcp-profile-switch
description: "List and activate gcloud configurations (profiles). Trigger: /cf-tools-gcp-profile-switch"
trigger: /cf-tools-gcp-profile-switch
version: 1.0.0
---

# /cf-tools-gcp-profile-switch

List and switch between gcloud named configurations. A configuration bundles `account`, `project`, `region`, `zone` etc. Activation is persistent (gcloud writes the choice to `~/.config/gcloud/active_config`).

## Usage

```
/cf-tools-gcp-profile-switch                       # list configurations + show active
/cf-tools-gcp-profile-switch <config-name>         # activate
/cf-tools-gcp-profile-switch --whoami              # show active + caller identity
/cf-tools-gcp-profile-switch --new <name>          # create + activate new config
```

Arguments:
1. `config-name` (optional) — activate this configuration
2. `--whoami` — show active config, account, project
3. `--new <name>` — create a brand-new configuration (will prompt for account + project)

## Prerequisites

```bash
command -v gcloud >/dev/null 2>&1 || {
  echo "ERROR: gcloud not installed."
  echo "Install: brew install --cask google-cloud-sdk    (macOS)"
  echo "         https://cloud.google.com/sdk/docs/install (Linux/Windows)"
  exit 1
}
```

## What You Must Do When Invoked

### Step 1 — List mode

```bash
gcloud config configurations list --format="table(name,is_active,properties.core.account,properties.core.project,properties.compute.region,properties.compute.zone)"
```

Sample shape:
```
NAME       IS_ACTIVE  ACCOUNT             PROJECT          REGION       ZONE
default    True       you@example.com     my-prod-12345    us-central1  us-central1-a
staging    False      you@example.com     my-stage-67890   us-east1     us-east1-b
sandbox    False      sandbox@example.com playground       europe-west1 europe-west1-d
```

### Step 2 — Activate mode

```bash
if gcloud config configurations describe "$NAME" >/dev/null 2>&1; then
  gcloud config configurations activate "$NAME"
  echo "Activated: $NAME"
else
  echo "ERROR: configuration '$NAME' not found"
  gcloud config configurations list --format="value(name)"
  exit 1
fi
```

`activate` is persistent — no `eval` needed (unlike AWS).

### Step 3 — `--whoami`

```bash
ACTIVE=$(gcloud config configurations list --filter="is_active=true" --format="value(name)")
ACCOUNT=$(gcloud config get-value account 2>/dev/null)
PROJECT=$(gcloud config get-value project 2>/dev/null)
REGION=$(gcloud config get-value compute/region 2>/dev/null)

echo "Active config:  $ACTIVE"
echo "Account:        $ACCOUNT"
echo "Project:        $PROJECT"
echo "Region:         $REGION"
gcloud auth list --filter="status:ACTIVE" --format="value(account)"
```

If account is empty or token expired:
```
(no active credentials — run: gcloud auth login)
```

### Step 4 — `--new <name>`

```bash
gcloud config configurations create "$NAME"
gcloud auth login
gcloud config set project "<prompt user>"
gcloud config set compute/region "<prompt user>"
```

Don't auto-pick a project — list available and ask:
```bash
gcloud projects list --format="table(projectId,name,projectNumber)"
```

## Output Contract

```
## gcloud configurations

**Config dir:**  ~/.config/gcloud/configurations/
**Active:**      <name>
**Account:**     <email>
**Project:**     <project-id>
**Region:**      <region>

NAME       IS_ACTIVE  ACCOUNT  PROJECT  REGION  ZONE
...

To switch:  /cf-tools-gcp-profile-switch <name>
To verify:  gcloud auth list
```

## Gotchas

- **Persistent switch**: unlike AWS, `gcloud config configurations activate` rewrites the active pointer on disk. Affects every new shell + every running shell on next gcloud call. No `eval` needed.
- **Per-config credentials**: each config can have its own active account, but credentials are shared in `~/.config/gcloud/credentials.db`. Switching config does NOT log out the previous account.
- **`gcloud auth login` is interactive**: opens a browser. In CI use `gcloud auth activate-service-account --key-file=...` instead.
- **Application Default Credentials (ADC)**: separate from `gcloud auth login`. Many SDKs read ADC, not gcloud config. Run `gcloud auth application-default login` if SDK code can't see credentials.
- **Expired tokens**: `gcloud config get-value account` returns the email even if the token is dead. Check with `gcloud auth print-access-token` (fails on expiry).
- **`--quiet` flag**: prefix `gcloud` calls with `--quiet` in scripts to skip confirmation prompts. Don't use for `auth login` (needs browser).

## Cross-Platform Notes

- **macOS**: configs live in `~/.config/gcloud/`.
- **Linux**: same.
- **Windows**: `%APPDATA%\gcloud\configurations\`.
- **WSL**: gcloud installed inside WSL has its own config dir; the host Windows install is separate. Pick one and stick with it.
