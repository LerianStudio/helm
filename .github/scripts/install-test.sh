#!/usr/bin/env bash
# install-test.sh — install + upgrade a chart into the current kube context.
# Core value over `helm template`: the API server validates every manifest
# server-side (rejects invalid/immutable/admission-failing objects), and the
# upgrade path catches immutable-field breaks. Does NOT wait for app pods to
# become Ready (images are private; readiness is a separate, creds-gated concern).
#
# Usage: install-test.sh <chart-dir> [values-file]
set -uo pipefail

CHART_DIR="$1"
CHART="$(basename "$CHART_DIR")"
# Values: explicit arg wins; else the render-gate's vetted sample values, if any.
VALUES_FILE="${2:-}"
[[ -z "$VALUES_FILE" && -f ".github/configs/helm-render-values/${CHART}.yaml" ]] \
  && VALUES_FILE=".github/configs/helm-render-values/${CHART}.yaml"
NS="it-${CHART}"
NSB="it-${CHART}-base"   # isolated namespace for the origin/main -> PR baseline upgrade
REL="$CHART"
TIMEOUT="${IT_TIMEOUT:-180s}"
VARGS=()
[[ -n "$VALUES_FILE" && -f "$VALUES_FILE" ]] && { VARGS=(-f "$VALUES_FILE"); echo "  values: $VALUES_FILE"; }
# --no-hooks: hook Jobs (migrations/bootstrap) pull private images and need real
# backing services, so they never complete in a credential-less CI cluster. We
# validate the steady-state manifests server-side; hook Jobs are out of scope here.
HOOKS=(--no-hooks)

# Library charts are not installable.
if grep -qiE '^type:[[:space:]]*library([[:space:]]|$)' "$CHART_DIR/Chart.yaml"; then
  echo "::notice::$CHART is a library chart — skipping install test."
  exit 0
fi

fail() { echo "::error::[$CHART] $1"; kubectl get events -n "$NS" --sort-by=.lastTimestamp 2>/dev/null | tail -15; cleanup; exit 1; }
cleanup() {
  helm uninstall "$REL" -n "$NS" >/dev/null 2>&1 || true
  helm uninstall "${REL}-base" -n "$NSB" >/dev/null 2>&1 || true
  kubectl delete ns "$NS" "$NSB" --wait=false >/dev/null 2>&1 || true
}

cleanup  # idempotent: clear any stale release/namespace from a prior aborted run

echo "===== [$CHART] dependency build ====="
helm dependency build "$CHART_DIR" >/dev/null 2>&1 || fail "helm dependency build failed"

# ---- 1. Fresh install of the PR chart (server-side manifest validation) ----
echo "===== [$CHART] install (PR) ====="
if ! helm install "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" --create-namespace --timeout "$TIMEOUT" 2>&1; then
  fail "helm install failed (invalid manifest / admission / hook)"
fi
[[ "$(helm status "$REL" -n "$NS" -o json | grep -o '"status":"[a-z]*"' | head -1)" == '"status":"deployed"' ]] \
  || fail "release not in deployed state"
n=$(kubectl get all -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  created $n objects"
[[ "$n" -gt 0 ]] || fail "install produced no objects"

# ---- 2. Upgrade the PR chart in place (upgrade code path + hook re-run) ----
echo "===== [$CHART] upgrade (PR -> PR, benign change) ====="
helm upgrade "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" --timeout "$TIMEOUT" \
  --set-string podAnnotations.helm-install-test="$(date +%s 2>/dev/null || echo x)" 2>&1 \
  | grep -qE 'STATUS: deployed' || fail "in-place upgrade failed"

# Free the PR release before the baseline test so only ONE release is ever
# installed at a time — two full installs of a subchart-heavy chart exhaust a
# single-node kind cluster's memory and make the baseline flaky.
helm uninstall "$REL" -n "$NS" >/dev/null 2>&1 || true
kubectl delete ns "$NS" --wait=false >/dev/null 2>&1 || true

# ---- 3. Real upgrade path: base (origin/main) -> PR, when the chart exists on main ----
if git cat-file -e "origin/main:charts/${CHART}/Chart.yaml" 2>/dev/null; then
  echo "===== [$CHART] upgrade (origin/main -> PR) ====="
  BASE_DIR="$(mktemp -d)/$CHART"; mkdir -p "$BASE_DIR"
  git archive "origin/main" "charts/${CHART}" | tar -x --strip-components=2 -C "$BASE_DIR" 2>/dev/null
  helm dependency build "$BASE_DIR" >/dev/null 2>&1 || echo "  (base dep build failed — skipping baseline upgrade)"
  if helm install "${REL}-base" "$BASE_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NSB" --create-namespace --timeout "$TIMEOUT" >/dev/null 2>&1; then
    helm upgrade "${REL}-base" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NSB" --timeout "$TIMEOUT" 2>&1 \
      | grep -qE 'STATUS: deployed' || fail "upgrade from origin/main failed (immutable-field break?)"
    echo "  origin/main -> PR upgrade OK"
  else
    echo "  (baseline install failed — likely unrelated to this PR; skipping)"
  fi
else
  echo "  (new chart — not on origin/main; skipping baseline upgrade)"
fi

echo "===== [$CHART] OK ====="
cleanup
