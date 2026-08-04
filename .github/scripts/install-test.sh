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
REL="$CHART"
NS="it-${CHART}"          # release namespace (helm -n); also created
TARGETS=""                # every distinct namespace the chart's manifests reference (created too)
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
  helm uninstall "${REL}-base" -n "$NS" >/dev/null 2>&1 || true
  for x in "$NS" $TARGETS; do kubectl delete ns "$x" --wait=false >/dev/null 2>&1 || true; done
}
# (Re)create the release namespace + every namespace the chart pins, then install.
do_install() { # <release> <chart-dir>
  for x in "$NS" $TARGETS; do kubectl create ns "$x" >/dev/null 2>&1 || true; done
  helm install "$1" "$2" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" --timeout "$TIMEOUT" 2>&1
}
deployed() { [[ "$(helm status "$1" -n "$NS" -o json 2>/dev/null | tr -d ' \n' | grep -o '"status":"[a-z]*"' | head -1)" == '"status":"deployed"' ]]; }

echo "===== [$CHART] dependency build ====="
# `helm dependency build` needs every HTTP dependency repo registered first
# (oci:// and file:// deps don't). Mirror what the render-gate's Go tool does:
# register each `repository: https://…` from Chart.yaml before building.
depn=0
while IFS= read -r repo_url; do
  [[ -z "$repo_url" ]] && continue
  helm repo add "dep${depn}" "$repo_url" >/dev/null 2>&1 || true
  depn=$((depn + 1))
done < <(grep -E 'repository:[[:space:]]*"?https?://' "$CHART_DIR/Chart.yaml" | grep -Eo 'https?://[^"[:space:]]+' | sort -u)
[[ "$depn" -gt 0 ]] && helm repo update >/dev/null 2>&1
helm dependency build "$CHART_DIR" >/dev/null 2>&1 || fail "helm dependency build failed"

# Lerian charts pin their own namespaces (namespaceOverride / global.namespace), so
# resources land there regardless of `-n` — and some charts even span MORE than one
# (most in the release ns, a few in a fixed one). Create EVERY namespace the render
# references instead of fighting it; the release itself lives in $NS.
TARGETS="$(helm template "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" 2>/dev/null \
            | awk '/^  namespace:/{gsub(/"/,"",$2); print $2}' | awk 'NF' | sort -u | grep -vxF "$NS" | tr '\n' ' ')"
echo "  namespaces: $NS${TARGETS:+ + $TARGETS}"

cleanup  # idempotent: clear any stale release/namespace from a prior aborted run

# ---- 1. Fresh install of the PR chart (server-side manifest validation) ----
echo "===== [$CHART] install (PR) ====="
do_install "$REL" "$CHART_DIR" || fail "helm install failed (invalid manifest / admission / hook)"
deployed "$REL" || fail "release not in deployed state"
n=0; for x in "$NS" $TARGETS; do n=$((n + $(kubectl get all -n "$x" --no-headers 2>/dev/null | wc -l))); done
echo "  created $n objects"
[[ "$n" -gt 0 ]] || fail "install produced no objects"

# ---- 2. Upgrade the PR chart in place (upgrade code path) ----
# Same values on purpose: a no-change upgrade still re-renders and re-applies
# (new revision, STATUS deployed). Forcing a value change is unsafe — a strict
# root-closed schema (e.g. br-sfn) rejects an injected podAnnotations key.
echo "===== [$CHART] upgrade (PR -> PR) ====="
helm upgrade "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" --timeout "$TIMEOUT" >/dev/null 2>&1 \
  && deployed "$REL" || fail "in-place upgrade failed"

# Free the PR release before the baseline so only ONE release is ever installed at
# a time — two full installs of a subchart-heavy chart exhaust a single-node kind
# cluster's memory. The baseline reuses the same (chart-pinned) namespace.
cleanup

# ---- 3. Real upgrade path: base (origin/main) -> PR, when the chart exists on main ----
if git cat-file -e "origin/main:charts/${CHART}/Chart.yaml" 2>/dev/null; then
  echo "===== [$CHART] upgrade (origin/main -> PR) ====="
  BASE_DIR="$(mktemp -d)/$CHART"; mkdir -p "$BASE_DIR"
  git archive "origin/main" "charts/${CHART}" | tar -x --strip-components=2 -C "$BASE_DIR" 2>/dev/null
  helm dependency build "$BASE_DIR" >/dev/null 2>&1 || echo "  (base dep build failed — skipping baseline)"
  if do_install "${REL}-base" "$BASE_DIR" >/dev/null 2>&1 && deployed "${REL}-base"; then
    helm upgrade "${REL}-base" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} "${HOOKS[@]}" -n "$NS" --timeout "$TIMEOUT" >/dev/null 2>&1 \
      && deployed "${REL}-base" || fail "upgrade from origin/main failed (immutable-field break?)"
    echo "  origin/main -> PR upgrade OK"
  else
    echo "  (baseline install failed — likely unrelated to this PR; skipping)"
  fi
else
  echo "  (new chart — not on origin/main; skipping baseline upgrade)"
fi

echo "===== [$CHART] OK ====="
cleanup
