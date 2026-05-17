---
name: cf-tools-aws-profile-switch
description: "List and switch between AWS named profiles from ~/.aws/credentials and ~/.aws/config. Trigger: /cf-tools-aws-profile-switch"
trigger: /cf-tools-aws-profile-switch
version: 1.0.0
---

# /cf-tools-aws-profile-switch

List AWS named profiles configured locally and switch the active profile via `AWS_PROFILE` (current shell) or print a `--profile` argument for ad-hoc use. Read-only by default — environment is only mutated when the user explicitly evals the printed line.

## Usage

```
/cf-tools-aws-profile-switch                    # list all profiles + show current
/cf-tools-aws-profile-switch <profile-name>     # print eval line to activate
/cf-tools-aws-profile-switch --whoami           # show current profile + identity
```

Arguments:
1. `profile-name` (optional) — switches `AWS_PROFILE` for the current shell when its output is `eval`-ed
2. `--whoami` (optional flag) — prints active profile + caller identity (calls `sts get-caller-identity` if creds work)

## What You Must Do When Invoked

### Step 1 — Verify CLI

```bash
if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI not installed."
  echo "Install: brew install awscli   (macOS)"
  echo "        apt install awscli     (Debian/Ubuntu)"
  echo "Docs:   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi
```

### Step 2 — Discover profiles

```bash
# AWS reads from two files. credentials has [profile] sections by raw name;
# config uses [profile <name>] except for [default].
CRED_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
CONF_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

profiles_from_credentials() {
  [ -f "$CRED_FILE" ] || return 0
  grep -E '^\[[^]]+\]$' "$CRED_FILE" | tr -d '[]'
}

profiles_from_config() {
  [ -f "$CONF_FILE" ] || return 0
  grep -E '^\[(profile [^]]+|default)\]$' "$CONF_FILE" \
    | sed -E 's/^\[(profile )?//; s/\]$//'
}

PROFILES=$( (profiles_from_credentials; profiles_from_config) | sort -u )
CURRENT="${AWS_PROFILE:-default}"
```

### Step 3 — List mode (no args)

Render a table: `*` next to the active profile.

```
PROFILES
  * default
    prod
    staging
    sandbox

Active: default   (AWS_PROFILE=<unset, falls back to default>)

To switch:     eval "$(/cf-tools-aws-profile-switch prod)"
To inspect:    /cf-tools-aws-profile-switch --whoami
```

### Step 4 — Switch mode

If `$1` is a profile name AND appears in `$PROFILES`:

```bash
echo "export AWS_PROFILE=$1"
echo "# Run: eval \"\$(/cf-tools-aws-profile-switch $1)\""
```

If profile missing, print available profiles and exit 1.

### Step 5 — `--whoami` mode

```bash
echo "Active AWS_PROFILE: ${AWS_PROFILE:-default}"
aws sts get-caller-identity --output table 2>&1 \
  || echo "(credentials invalid or expired — re-auth with: aws sso login --profile $CURRENT)"
```

## Output Contract

```
## AWS profiles

**Config:**        ~/.aws/config
**Credentials:**   ~/.aws/credentials
**Active:**        <profile>   (source: env AWS_PROFILE | default)
**Available:**     <N> profiles

  * <active-profile>     (region: us-east-1, sso: yes/no)
    <other-profile>

To switch:    eval "$(/cf-tools-aws-profile-switch <name>)"
To verify:    aws sts get-caller-identity
```

## Gotchas

- **Profile in config but not credentials**: SSO and `credential_process` profiles only live in `~/.aws/config`. Don't filter to credentials-only.
- **`default` is special**: in config it is `[default]`, not `[profile default]`. Handle both.
- **Stale SSO sessions**: `aws sts get-caller-identity` returns `ExpiredToken`. Suggest `aws sso login --profile <name>`.
- **AWS_DEFAULT_PROFILE vs AWS_PROFILE**: both work but `AWS_PROFILE` wins. Standardize on `AWS_PROFILE`.
- **Subshell trap**: setting `AWS_PROFILE` inside this skill's bash only affects the subshell. User must `eval` the output for it to persist in their shell.
- **Region**: switching profile does not change `AWS_REGION` — if region is needed, mention it explicitly.

## Cross-Platform Notes

- **macOS**: `~/.aws/credentials` is the default location.
- **Linux**: same path; honor `AWS_SHARED_CREDENTIALS_FILE` / `AWS_CONFIG_FILE` env overrides.
- **Windows / WSL**: `%USERPROFILE%\.aws\credentials`. In WSL, the Linux home is preferred; check both if user reports profiles missing.
