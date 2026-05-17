---
name: cf-tools-k8s-kubectx-switch
description: "List or switch kubeconfig contexts by partial match, with kubectx fallback to plain kubectl. Trigger: /cf-tools-k8s-kubectx-switch"
trigger: /cf-tools-k8s-kubectx-switch
version: 1.0.0
---

# /cf-tools-k8s-kubectx-switch

Switch the active Kubernetes context by partial-name match. Prefers `kubectx` (better UX, fzf integration). Falls back to `kubectl config use-context` with custom match logic when kubectx is not installed.

## Usage

```
/cf-tools-k8s-kubectx-switch                # list all contexts, mark current
/cf-tools-k8s-kubectx-switch prod           # switch to context matching "prod"
/cf-tools-k8s-kubectx-switch eks-staging
/cf-tools-k8s-kubectx-switch -               # toggle to previous context
/cf-tools-k8s-kubectx-switch --namespace=monitoring   # also set default namespace
```

Arguments:
- `<partial>` — substring of context name; switches if exactly one matches
- `-` — switch to previous context (kubectx feature; emulated with state file as fallback)
- `--namespace=<ns>` — set default namespace for the (newly) current context

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl not installed."
  echo "Install: brew install kubectl    # macOS"
  echo "         apt install kubectl     # Linux"
  exit 1
}

HAS_KUBECTX=0
command -v kubectx >/dev/null 2>&1 && HAS_KUBECTX=1
HAS_KUBENS=0
command -v kubens >/dev/null 2>&1 && HAS_KUBENS=1

if [ "$HAS_KUBECTX" = "0" ]; then
  echo "Note: kubectx not installed — using kubectl fallback."
  echo "      Install for nicer UX: brew install kubectx"
fi
```

### Step 2 — Handle list mode (no arg)

```bash
if [ -z "$ARG" ]; then
  if [ "$HAS_KUBECTX" = "1" ]; then
    kubectx
  else
    CURRENT=$(kubectl config current-context 2>/dev/null)
    echo "Contexts (current marked with ★):"
    kubectl config get-contexts -o name | while read ctx; do
      if [ "$ctx" = "$CURRENT" ]; then
        echo "  ★ $ctx"
      else
        echo "    $ctx"
      fi
    done
  fi
  exit 0
fi
```

### Step 3 — Handle toggle (-)

```bash
if [ "$ARG" = "-" ]; then
  if [ "$HAS_KUBECTX" = "1" ]; then
    kubectx -
  else
    PREV_FILE="$HOME/.kube/.cf-prev-context"
    if [ ! -f "$PREV_FILE" ]; then
      echo "ERROR: No previous context recorded (no kubectx, no state file)."
      exit 1
    fi
    PREV=$(cat "$PREV_FILE")
    CURRENT=$(kubectl config current-context)
    kubectl config use-context "$PREV"
    echo "$CURRENT" > "$PREV_FILE"
  fi
  exit 0
fi
```

### Step 4 — Partial match switch

```bash
CONTEXTS=$(kubectl config get-contexts -o name)
MATCHES=$(echo "$CONTEXTS" | grep -i "$ARG" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)

case "$COUNT" in
  0)
    echo "ERROR: no context matches '$ARG'"
    echo "Available:"
    echo "$CONTEXTS" | sed 's/^/  /'
    exit 1
    ;;
  1)
    TARGET="$MATCHES"
    ;;
  *)
    # Try exact match within the multi-match set
    EXACT=$(echo "$MATCHES" | grep -x "$ARG" || true)
    if [ -n "$EXACT" ]; then
      TARGET="$EXACT"
    else
      echo "ERROR: '$ARG' matches multiple contexts. Be more specific:"
      echo "$MATCHES" | sed 's/^/  /'
      exit 1
    fi
    ;;
esac

# Save current as previous before switching (for our fallback toggle)
CURRENT=$(kubectl config current-context 2>/dev/null)
[ -n "$CURRENT" ] && echo "$CURRENT" > "$HOME/.kube/.cf-prev-context"

kubectl config use-context "$TARGET"
echo "✅ Switched to: $TARGET"
```

### Step 5 — Optional namespace set

```bash
if [ -n "$NAMESPACE" ]; then
  if [ "$HAS_KUBENS" = "1" ]; then
    kubens "$NAMESPACE"
  else
    kubectl config set-context --current --namespace="$NAMESPACE"
  fi
  echo "✅ Namespace set to: $NAMESPACE"
fi
```

### Step 6 — Verify reachability

```bash
echo
echo "Verifying cluster reachability..."
if kubectl cluster-info >/dev/null 2>&1; then
  SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  echo "✅ Reachable at $SERVER"
else
  echo "⚠️  Context switched but cluster unreachable (VPN? credentials expired?)"
fi
```

## Output Contract

```
## kubectx switch

**Tool:**       kubectx | kubectl (fallback)
**Previous:**   <ctx>
**Current:**    <ctx>
**Namespace:**  <ns> (if --namespace used)
**Cluster:**    <server URL>
**Reachable:**  ✅ | ⚠️ unreachable
```

## Gotchas

- **`kubectx` is a 60-line bash script** wrapping `kubectl config`. It adds: tab completion, fzf interactive picker, `-` for toggle, colored output. Install: `brew install kubectx` (Linux: `apt install kubectx` or download from https://github.com/ahmetb/kubectx).
- **Partial match ambiguity**: `prod` matches `eks-prod`, `prod-east-1`, `prod-canary`. Skill bails with a list rather than picking arbitrarily.
- **Multiple kubeconfigs**: `KUBECONFIG=~/.kube/config:~/.kube/work.yml` lets you merge. Contexts from all files appear, but writes go to the FIRST file unless `--kubeconfig` is set. Switching context updates current-context in the first file.
- **Stale tokens**: switching to a context whose token expired (common with AWS EKS) makes `kubectl cluster-info` fail. User must re-auth (`aws eks update-kubeconfig --name ...`).
- **No cluster during skill auth verification** — preflight is the safety net.
- **`kubens` companion** to `kubectx` switches namespaces. Worth recommending alongside.

## Cross-Platform Notes

- **macOS**: `brew install kubectx` installs both `kubectx` and `kubens`.
- **Linux**: distro package or `git clone https://github.com/ahmetb/kubectx /opt/kubectx && ln -s /opt/kubectx/kubectx /usr/local/bin/`.
- **Windows**: not directly supported; use `kubectl config use-context` or install via WSL2.
- **fzf integration**: if `fzf` is on PATH, `kubectx` and `kubens` give interactive pickers — recommend `brew install fzf` for the best UX.
