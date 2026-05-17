---
name: cf-tools-k8s-pod-restart
description: "Rollout restart a deployment/statefulset/daemonset and wait until all pods are Ready. Trigger: /cf-tools-k8s-pod-restart"
trigger: /cf-tools-k8s-pod-restart
version: 1.0.0
---

# /cf-tools-k8s-pod-restart

Trigger a rolling restart of a workload (no image change required) and wait for the rollout to complete. Uses `kubectl rollout restart` + `kubectl rollout status`. Reports time taken and verifies all pods are Ready.

## Usage

```
/cf-tools-k8s-pod-restart deploy/web
/cf-tools-k8s-pod-restart sts/postgres --namespace=db
/cf-tools-k8s-pod-restart ds/fluentd --timeout=10m
/cf-tools-k8s-pod-restart deploy/web --wait=false           # fire and forget
```

Arguments:
- `<workload>` (required) — must be `deploy/<name>`, `deployment/<name>`, `sts/<name>`, `statefulset/<name>`, `ds/<name>`, `daemonset/<name>`
- `--namespace=<ns>` (default: current context's)
- `--timeout=<dur>` (default `5m`) — wait timeout
- `--wait=false` — don't wait for rollout to complete

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl not installed. Install: brew install kubectl"
  exit 1
}
kubectl version --client >/dev/null 2>&1 || { echo "ERROR: kubectl broken."; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: no cluster reachable."; exit 1; }
```

### Step 2 — Validate workload kind

```bash
case "$WORKLOAD" in
  deploy/*|deployment/*|sts/*|statefulset/*|ds/*|daemonset/*) ;;
  *)
    echo "ERROR: workload must be deploy/, sts/, or ds/ — got: $WORKLOAD"
    exit 1
    ;;
esac

NS_FLAG=()
[ -n "$NAMESPACE" ] && NS_FLAG=( -n "$NAMESPACE" )

# Confirm it exists before touching it
if ! kubectl get "$WORKLOAD" "${NS_FLAG[@]}" >/dev/null 2>&1; then
  echo "ERROR: $WORKLOAD not found in namespace ${NAMESPACE:-(current)}"
  exit 1
fi

echo "Current state:"
kubectl get "$WORKLOAD" "${NS_FLAG[@]}"
```

### Step 3 — Trigger restart

```bash
START=$(date +%s)
echo "Restarting $WORKLOAD..."
kubectl rollout restart "$WORKLOAD" "${NS_FLAG[@]}"
```

`kubectl rollout restart` works by patching a `kubectl.kubernetes.io/restartedAt` annotation on the pod template, which triggers the controller to roll new pods. No image or env change required.

### Step 4 — Wait for rollout (default behavior)

```bash
TIMEOUT="${TIMEOUT:-5m}"

if [ "$WAIT" != "false" ]; then
  echo "Waiting for rollout to complete (timeout: $TIMEOUT)..."
  if kubectl rollout status "$WORKLOAD" "${NS_FLAG[@]}" --timeout="$TIMEOUT"; then
    END=$(date +%s)
    ELAPSED=$((END - START))
    echo "✅ Rollout complete in ${ELAPSED}s"
  else
    echo "❌ Rollout did not finish within $TIMEOUT"
    echo "Check: kubectl describe $WORKLOAD ${NS_FLAG[*]}"
    echo "Recent events:"
    kubectl get events "${NS_FLAG[@]}" --sort-by=.lastTimestamp | tail -20
    exit 1
  fi
fi
```

### Step 5 — Verify

```bash
echo
echo "Post-restart pod status:"
LABEL=$(kubectl get "$WORKLOAD" "${NS_FLAG[@]}" -o jsonpath='{.spec.selector.matchLabels}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(f'{k}={v}' for k,v in d.items()))")
kubectl get pods "${NS_FLAG[@]}" -l "$LABEL" -o wide
```

## Output Contract

```
## kubectl rollout restart

**Workload:**    <kind/name>
**Namespace:**   <ns>
**Duration:**    <Ns>
**Pods Ready:**  <N>/<N>
**Result:**      ✅ rollout complete | ❌ timeout/failed
**Events:**      (last 5 lines if failed)
```

## Gotchas

- **StatefulSet restart is one-at-a-time** (ordinal order). A 10-replica StatefulSet takes ~10× longer than a 10-replica Deployment.
- **PodDisruptionBudget** can block rollout if it would violate minAvailable. Symptom: rollout status hangs without progress. Check `kubectl get pdb`.
- **Init containers**: a slow init container counts toward the rollout time. Expect `Init:0/N` in pod status.
- **Image pull during restart**: if a new image was pushed to the same tag (mutable tag — bad practice), pods will pull it. Combined with `imagePullPolicy: Always`, this can be a hidden image upgrade. Use immutable tags or digests.
- **`--timeout`** is wall-clock from `rollout status` start; if rollout takes 4m59s on a 5m timeout you're fine, 5m1s and you've "failed" — bump timeout for slow workloads.
- **No cluster during skill auth verification** — kubectl client was also missing on dev machine. Preflight catches both.

## Cross-Platform Notes

Identical across platforms. Kubectl client behavior is OS-agnostic; differences are in the cluster (managed vs self-hosted, version skew). Verify with `kubectl version` that client/server skew is within 1 minor version.
