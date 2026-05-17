---
name: cf-tools-k8s-pod-logs
description: "Tail pod logs by label selector across one or many pods side-by-side. Trigger: /cf-tools-k8s-pod-logs"
trigger: /cf-tools-k8s-pod-logs
version: 1.0.0
---

# /cf-tools-k8s-pod-logs

Tail logs for pods matched by selector (label, name pattern, or deployment). Prefixes each line with `[pod-name]` so multi-replica output stays readable. Supports `--since`, `--lines`, `--follow`, `--container`, and previous-container logs for crash debugging.

## Usage

```
/cf-tools-k8s-pod-logs <selector>
/cf-tools-k8s-pod-logs app=web                            # by label
/cf-tools-k8s-pod-logs deploy/web                         # by deployment
/cf-tools-k8s-pod-logs web-                               # by name prefix
/cf-tools-k8s-pod-logs app=web --follow --since=5m
/cf-tools-k8s-pod-logs app=web --lines=200 --container=sidecar
/cf-tools-k8s-pod-logs app=web --previous                 # crashed container's prior logs
/cf-tools-k8s-pod-logs app=web --namespace=staging
```

Arguments:
- `<selector>` (required) — label (`k=v`), `deploy/<name>`, `sts/<name>`, or name prefix
- `--since=<duration>` (default `10m`)
- `--lines=<N>` — last N lines per pod (overrides `--since`)
- `--follow` — stream
- `--container=<name>` — multi-container pod, pick one (default: first)
- `--previous` — logs from previous (crashed) container
- `--namespace=<ns>` (default: current context's namespace)

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not installed."
  echo "Install: brew install kubectl    # macOS"
  echo "         apt install kubectl     # Debian/Ubuntu"
  echo "         https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Verify binary works (does NOT require a cluster)
kubectl version --client >/dev/null 2>&1 || { echo "ERROR: kubectl binary broken."; exit 1; }

# Quick cluster reachability check
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl can't reach a cluster. Check current context: kubectl config current-context"
  exit 1
fi
```

### Step 2 — Resolve selector to pod list

```bash
NS_FLAG=()
[ -n "$NAMESPACE" ] && NS_FLAG=( -n "$NAMESPACE" )

case "$SELECTOR" in
  deploy/*|deployment/*|sts/*|statefulset/*|rs/*|ds/*|job/*)
    # Workload selector — let kubectl logs handle it directly
    PODS=("$SELECTOR")
    MULTI_VIA_KUBECTL=1
    ;;
  *=*)
    # Label selector
    PODS=($(kubectl get pods "${NS_FLAG[@]}" -l "$SELECTOR" -o jsonpath='{.items[*].metadata.name}'))
    ;;
  *)
    # Name prefix
    PODS=($(kubectl get pods "${NS_FLAG[@]}" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "^$SELECTOR" || true))
    ;;
esac

if [ ${#PODS[@]} -eq 0 ]; then
  echo "No pods match selector: $SELECTOR"
  exit 0
fi
echo "Matched ${#PODS[@]} pod(s): ${PODS[*]}"
```

### Step 3 — Build kubectl logs flags

```bash
SINCE="${SINCE:-10m}"
LOG_FLAGS=( --timestamps )
[ -n "$LINES" ] && LOG_FLAGS+=( --tail "$LINES" ) || LOG_FLAGS+=( --since "$SINCE" )
[ "$FOLLOW" = "1" ] && LOG_FLAGS+=( --follow )
[ "$PREVIOUS" = "1" ] && LOG_FLAGS+=( --previous )
[ -n "$CONTAINER" ] && LOG_FLAGS+=( -c "$CONTAINER" )
```

### Step 4a — Single pod / workload selector

```bash
if [ ${#PODS[@]} -eq 1 ]; then
  kubectl logs "${NS_FLAG[@]}" "${LOG_FLAGS[@]}" "${PODS[0]}"
  exit $?
fi
```

### Step 4b — Multi-pod fan-in

```bash
PIDS=()
trap 'kill ${PIDS[@]} 2>/dev/null' INT TERM EXIT

for p in "${PODS[@]}"; do
  ( kubectl logs "${NS_FLAG[@]}" "${LOG_FLAGS[@]}" "$p" 2>&1 | sed "s/^/[$p] /" ) &
  PIDS+=($!)
done
wait
```

## Output Contract

```
## kubectl pod logs

**Selector:**  <selector>
**Namespace:** <ns>
**Pods:**      <N>: pod-a, pod-b, …
**Window:**    --since=<dur> | --tail=<N>
**Container:** <c> | default
**Follow:**    yes | no
**Total lines:** <N>
```

## Gotchas

- **Label selectors** support multiple keys: `-l app=web,env=prod`. Comma-separated, NOT spaces.
- **`--previous` only works** if the container restarted. On a healthy pod: "previous terminated container not found". Useful right after a CrashLoopBackOff.
- **Multi-container pods**: without `--container`, kubectl defaults to the *first* container in spec order, which may not be the app container (could be an istio sidecar). Always log `kubectl get pod <name> -o jsonpath='{.spec.containers[*].name}'` for context.
- **`kubectl logs deploy/<name>`** auto-tails ALL pods owned by the deployment, but only ONE container per pod. For multi-container deployments you must specify `-c`.
- **`--since` is server-side** (kube-apiserver). Skew between client and server can cause "no logs" for very recent `--since` windows. Try `--since=15s` if `--since=5s` returns nothing.
- **No cluster during skill auth verification** — kubectl client binary was also missing on the dev machine. Document install (`brew install kubectl`) and let the user retry.

## Cross-Platform Notes

- **macOS**: `brew install kubectl` or use the version bundled with Docker Desktop.
- **Linux**: `apt install kubectl` (after adding the kubernetes apt repo) or `snap install kubectl --classic`.
- **Windows**: `choco install kubernetes-cli` or `scoop install kubectl`.
- **kubectx/kube-ps1** make multi-cluster work safer — pair with `/cf-tools-k8s-kubectx-switch`.
