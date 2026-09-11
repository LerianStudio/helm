#!/usr/bin/env bash
# install-test.sh — install + upgrade a chart into the current kube context.
# Core value over `helm template`: the API server validates every manifest
# server-side (rejects invalid/immutable/admission-failing objects), the upgrade
# path catches immutable-field breaks, and — when the cluster can pull the images —
# the workload actually has to start and pass its own probes.
#
# Two modes, chosen by whether the cluster holds registry credentials:
#
#   deep     hooks run, `--wait` holds until every pod is Ready. This is the mode
#            that catches an image tag nobody published and a liveness probe
#            pointed at an endpoint that lies.
#   shallow  --no-hooks, no waiting. Manifests are still validated server-side.
#            Used when there are no credentials to give the cluster (a fork PR).
#
# Usage: install-test.sh <chart-dir> [values-file]
set -uo pipefail

CHART_DIR="$1"
CHART="$(basename "$CHART_DIR")"
REL="$CHART"
NS="it-${CHART}"          # release namespace (helm -n); also created
TARGETS=""                # every distinct namespace the chart's manifests reference (created too)

# Values: an explicit argument replaces everything. Otherwise the render gate's
# vetted sample values go on first, and the install-specific file — present only
# for charts that need to be trimmed to fit a single-node cluster — is layered on
# top rather than replacing them, so neither file has to repeat the other.
VARGS=()
if [[ -n "${2:-}" ]]; then
  VARGS=(-f "$2"); echo "  values: $2"
else
  for candidate in ".github/configs/helm-render-values/${CHART}.yaml" \
                   ".github/configs/helm-install-values/${CHART}.yaml"; do
    [[ -f "$candidate" ]] && { VARGS+=(-f "$candidate"); echo "  values: $candidate"; }
  done
fi

# IT_PULL_SECRET names the image pull Secret to create in every namespace this run
# touches, built from the runner's docker config. Its absence — or a runner that
# never logged in, which is what a fork PR gets — means there is nothing to pull
# private images with, so the run degrades to manifest validation rather than
# failing for the wrong reason.
PULL_SECRET="${IT_PULL_SECRET:-}"
DOCKERCONFIG="${IT_DOCKERCONFIG:-$HOME/.docker/config.json}"
[[ -f "$DOCKERCONFIG" ]] || PULL_SECRET=""
if [[ -n "$PULL_SECRET" && "${IT_NO_HOOKS:-0}" != "1" ]]; then
  MODE=deep
  HOOKS=()
  WAIT=(--wait)
  TIMEOUT="${IT_TIMEOUT:-600s}"
else
  MODE=shallow
  # Hook Jobs (migrations/bootstrap) pull private images and need real backing
  # services, so without credentials they never complete.
  HOOKS=(--no-hooks)
  WAIT=()
  TIMEOUT="${IT_TIMEOUT:-180s}"
fi
echo "  mode: $MODE"

# Library charts are not installable.
if grep -qiE '^type:[[:space:]]*library([[:space:]]|$)' "$CHART_DIR/Chart.yaml"; then
  echo "::notice::$CHART is a library chart — skipping install test."
  exit 0
fi

# A `--wait` timeout says nothing about which pod refused to start. Without this
# dump the only way to tell an unpublished image from a probe pointed at the wrong
# path is to reproduce the whole run locally.
diagnose() {
  for x in "$NS" $TARGETS; do
    kubectl get pods -n "$x" -o wide 2>/dev/null | tail -n +1
    while IFS= read -r pod; do
      [[ -z "$pod" ]] && continue
      echo "--- describe $x/$pod ---"
      kubectl describe pod "$pod" -n "$x" 2>/dev/null | sed -n '/Events:/,$p' | head -20
      echo "--- logs $x/$pod ---"
      kubectl logs "$pod" -n "$x" --all-containers --tail=30 2>&1 | head -30
    done < <(kubectl get pods -n "$x" --no-headers 2>/dev/null \
               | awk '$3 != "Running" && $3 != "Completed" {print $1}')
  done
}
fail() {
  echo "::error::[$CHART] $1"
  kubectl get events -n "$NS" --sort-by=.lastTimestamp 2>/dev/null | tail -15
  [[ "$MODE" == deep ]] && diagnose
  cleanup
  exit 1
}
# Deletion is waited on, not fired and forgotten. do_install runs straight after
# cleanup, and a namespace still Terminating rejects the create — an error this
# script suppresses, so the install would then land in a dying namespace and fail
# for a reason nobody could read from the log.
cleanup() {
  helm uninstall "$REL" -n "$NS" >/dev/null 2>&1 || true
  helm uninstall "${REL}-base" -n "$NS" >/dev/null 2>&1 || true
  for x in "$NS" $TARGETS; do
    kubectl delete ns "$x" --wait=true --timeout=120s >/dev/null 2>&1 || true
  done
  for x in "$NS" $TARGETS; do
    if kubectl get ns "$x" >/dev/null 2>&1; then
      echo "::warning::[$CHART] namespace $x is still present after deletion — a stuck finalizer, most likely"
    fi
  done
}
# Create the pull secret in a namespace and make it the default for every pod
# scheduled there, so no chart has to expose an imagePullSecrets value for this.
# Built from the runner's own docker config, which already holds a login for every
# registry the job authenticated to — one Secret covers GHCR and Docker Hub alike.
grant_pull() { # <namespace>
  [[ -z "$PULL_SECRET" || ! -f "$DOCKERCONFIG" ]] && return 0
  kubectl create secret generic "$PULL_SECRET" -n "$1" \
    --from-file=".dockerconfigjson=${DOCKERCONFIG}" \
    --type=kubernetes.io/dockerconfigjson >/dev/null 2>&1 || true
  kubectl patch serviceaccount default -n "$1" \
    -p "{\"imagePullSecrets\":[{\"name\":\"${PULL_SECRET}\"}]}" >/dev/null 2>&1 || true
}
# (Re)create the release namespace + every namespace the chart pins, then install.
# <release> <chart-dir> [base] — `base` selects the baseline's own values instead
# of the pull request's. Installing origin/main's chart with the PR's values is how
# a new key meets the old schema: a chart with a closed schema rejects it, the
# baseline install fails, and the upgrade test it exists for gets skipped with a
# message blaming something unrelated.
do_install() {
  local rel="$1" dir="$2" kind="${3:-pr}"
  for x in "$NS" $TARGETS; do
    kubectl create ns "$x" >/dev/null 2>&1 || kubectl get ns "$x" >/dev/null 2>&1 || {
      echo "::error::[$CHART] could not create namespace $x"; return 1; }
    grant_pull "$x"
  done
  if [[ "$kind" == base ]]; then
    helm install "$rel" "$dir" ${BASE_VARGS[@]+"${BASE_VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} \
      -n "$NS" --timeout "$TIMEOUT" 2>&1
  else
    helm install "$rel" "$dir" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} \
      -n "$NS" --timeout "$TIMEOUT" 2>&1
  fi
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
# Build with one retry (dependency fetches are network-flaky) and surface the real
# error on final failure instead of a bare "build failed".
db_out="$(helm dependency build "$CHART_DIR" 2>&1)" \
  || db_out="$(helm dependency update "$CHART_DIR" 2>&1)" \
  || { echo "$db_out" | tail -8 | sed 's/^/    /'; fail "helm dependency build failed"; }

# Lerian charts pin their own namespaces (namespaceOverride / global.namespace), so
# resources land there regardless of `-n` — and some charts even span MORE than one
# (most in the release ns, a few in a fixed one). Create EVERY namespace the render
# references instead of fighting it; the release itself lives in $NS.
TARGETS="$(helm template "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} -n "$NS" 2>/dev/null \
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
helm upgrade "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} -n "$NS" --timeout "$TIMEOUT" >/dev/null 2>&1 \
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

  # The baseline is installed with the values as they exist on origin/main, taken
  # from git rather than the working tree so a values file the PR added or edited
  # does not reach the old chart. No file there means no -f, which is right: that
  # is how the chart was rendered on main.
  BASE_VALUES_DIR="$(mktemp -d)"
  BASE_VARGS=()
  for cand in "helm-render-values" "helm-install-values"; do
    src=".github/configs/${cand}/${CHART}.yaml"
    if git cat-file -e "origin/main:${src}" 2>/dev/null; then
      git show "origin/main:${src}" > "${BASE_VALUES_DIR}/${cand}.yaml"
      BASE_VARGS+=(-f "${BASE_VALUES_DIR}/${cand}.yaml")
    fi
  done
  [[ ${#BASE_VARGS[@]} -gt 0 ]] && echo "  baseline values: ${#BASE_VARGS[@]} file(s) from origin/main"

  helm dependency build "$BASE_DIR" >/dev/null 2>&1 || echo "  (base dep build failed — skipping baseline)"
  if do_install "${REL}-base" "$BASE_DIR" base >/dev/null 2>&1 && deployed "${REL}-base"; then
    helm upgrade "${REL}-base" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} -n "$NS" --timeout "$TIMEOUT" >/dev/null 2>&1 \
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
