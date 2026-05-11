#!/usr/bin/env bash
# PreCommit Hook: Secret Detection Gate
# Scans staged files for accidentally committed secrets
# Exit 1 to block the commit, exit 0 to allow

set -euo pipefail

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

found=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  # Skip binary files
  if file "$file" | grep -q "binary"; then
    continue
  fi

  content=$(cat "$file" 2>/dev/null || true)

  # AWS Access Keys
  if echo "$content" | grep -qE "AKIA[0-9A-Z]{16}"; then
    echo "BLOCKED: AWS Access Key found in $file"
    found=1
  fi

  # AWS Secret Keys
  if echo "$content" | grep -qE "['\"][0-9a-zA-Z/+]{40}['\"]"; then
    if echo "$content" | grep -qiE "aws|secret|key"; then
      echo "BLOCKED: Possible AWS Secret Key in $file"
      found=1
    fi
  fi

  # Private keys
  if echo "$content" | grep -qE "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY"; then
    echo "BLOCKED: Private key found in $file"
    found=1
  fi

  # GitHub tokens
  if echo "$content" | grep -qE "ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{82}"; then
    echo "BLOCKED: GitHub token found in $file"
    found=1
  fi

  # Generic API keys / secrets (high-entropy strings assigned to suspect variable names)
  if echo "$content" | grep -qiE "(api_key|apikey|secret_key|auth_token|access_token|password)\s*[=:]\s*['\"][a-zA-Z0-9/+_\-]{20,}['\"]"; then
    echo "WARNING: Possible hardcoded secret in $file"
    found=1
  fi

  # .env files that shouldn't be committed
  if [[ "$file" == *.env || "$file" == .env.* ]] && [[ "$file" != *.env.example && "$file" != *.env.template ]]; then
    echo "BLOCKED: .env file should not be committed: $file"
    found=1
  fi

done <<< "$STAGED_FILES"

if [ "$found" -gt 0 ]; then
  echo ""
  echo "Secret scan failed. Remove secrets before committing."
  echo "If this is a false positive, use --no-verify to bypass (not recommended)."
  exit 1
fi

exit 0
