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
# vetted sample values go on first, and the install-specific file is layered on
# top rather than replacing them, so neither file has to repeat the other. That
# file trims a chart to fit a single-node cluster, or picks which supported
# topology the gate installs; .github/configs/helm-install-values/README.md has
# the contract.
VARGS=()
if [[ -n "${2:-}" ]]; then
  VARGS=(-f "$2"); echo "  values (explicit): $2"
else
  for candidate in ".github/configs/helm-render-values/${CHART}.yaml" \
                   ".github/configs/helm-install-values/${CHART}.yaml"; do
    if [[ -f "$candidate" ]]; then
      VARGS+=(-f "$candidate"); echo "  values: $candidate"
    else
      echo "  values: $candidate (absent)"
    fi
  done
  [[ ${#VARGS[@]} -eq 0 ]] && echo "  values: none — installing with chart defaults"
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
      # --previous first: a CrashLoopBackOff pod is between restarts as often as
      # not, and the live container's log is then empty or a fresh boot — the run
      # that actually failed is the previous one.
      #
      # Read from the head in both cases, and never with --tail: a runtime that
      # panics prints the cause first and unwinds for pages after, so the last N
      # lines are the middle of a stack trace. --tail truncates server-side, before
      # head ever sees the output, so pairing the two just discards the beginning
      # twice over. A RabbitMQ boot failure is what proved it.
      echo "--- logs (previous) $x/$pod ---"
      kubectl logs "$pod" -n "$x" --all-containers --previous 2>&1 | head -80
      echo "--- logs (current) $x/$pod ---"
      kubectl logs "$pod" -n "$x" --all-containers 2>&1 | head -60
    done < <(kubectl get pods -n "$x" --no-headers 2>/dev/null \
               | awk '$3 != "Running" && $3 != "Completed" {print $1}')
  done
}
# Exit 2 marks the ONE failure class an allow-list entry tagged `readiness` may
# absorb: helm applied every manifest and `--wait` then gave up on a workload that
# never became Ready (helm says "not ready" / "context deadline exceeded" / "timed
# out waiting"). A render, admission, hook or immutable-field error exits 1, so a
# chart that only lacks a datastore in kind cannot hide a broken template behind
# that fact. A hook Job that never completes ALSO says "timed out waiting", but
# helm names the hook in the same message ("failed pre-install: ...",
# "pre-upgrade hooks failed: ..."), and that is a hook defect, not readiness.
readiness_rc() {
  grep -qE 'failed (pre|post)-(install|upgrade|rollback|delete)|hooks? failed' <<<"$1" && { echo 1; return; }
  grep -qE 'not ready|context deadline exceeded|timed out waiting' <<<"$1" && echo 2 || echo 1
}

fail() { # <message> [exit-code]
  echo "::error::[$CHART] $1"
  kubectl get events -n "$NS" --sort-by=.lastTimestamp 2>/dev/null | tail -15
  [[ "$MODE" == deep ]] && diagnose
  # These fixtures are written as charts break, not up front — nobody can guess
  # what a service needs at boot. So the failure has to say where the answer goes,
  # or the next person re-derives the whole thing from a pod log.
  cat <<HINT
::notice::[$CHART] If this is missing configuration rather than a chart defect:
  create .github/configs/helm-install-values/${CHART}.yaml with the values the
  workload needs to start. It is layered ON TOP of
  .github/configs/helm-render-values/${CHART}.yaml, so only the delta belongs
  there. The describe/logs output above is what it should be derived from.
  If the chart is genuinely broken, add it to
  .github/configs/helm-install-test-allow-failure.txt with a one-line reason.
HINT
  cleanup
  exit "${2:-1}"
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
# Bring a namespace to Active, or fail. Accepting any existing namespace — which is
# what `create || get` did — lets one still in Terminating through, and helm cannot
# create resources in a namespace that is going away; the install then fails with
# something that reads like a chart defect.
ensure_ns() { # <namespace>
  local ns="$1" waited=0 phase
  while :; do
    phase=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    case "$phase" in
      Active)      return 0 ;;
      "")          kubectl create ns "$ns" >/dev/null 2>&1 && return 0 ;;  # else lost a race; re-read
      Terminating) : ;;                                                     # wait it out
    esac
    if [ "$waited" -ge "${NS_WAIT:-120}" ]; then
      echo "::error::[$CHART] namespace $ns stuck in '${phase:-absent}' after ${waited}s"
      return 1
    fi
    sleep 5; waited=$((waited + 5))
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
    ensure_ns "$x" || return 1
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
render_targets() { # <chart-dir> [base]
  local dir="$1" kind="${2:-pr}" out
  if [ "$kind" = base ]; then
    out=$(helm template "$REL" "$dir" ${BASE_VARGS[@]+"${BASE_VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} -n "$NS" 2>/dev/null)
  else
    out=$(helm template "$REL" "$dir" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} -n "$NS" 2>/dev/null)
  fi
  printf '%s' "$out" | awk '/^  namespace:/{gsub(/"/,"",$2); print $2}' | awk 'NF' | sort -u | grep -vxF "$NS"
}

TARGETS="$(render_targets "$CHART_DIR" | tr '\n' ' ')"
echo "  namespaces: $NS${TARGETS:+ + $TARGETS}"

cleanup  # idempotent: clear any stale release/namespace from a prior aborted run

# ---- 1. Fresh install of the PR chart (server-side manifest validation) ----
echo "===== [$CHART] install (PR) ====="
out="$(do_install "$REL" "$CHART_DIR")" \
  || { printf '%s\n' "$out"; fail "helm install failed (invalid manifest / admission / hook / never Ready)" "$(readiness_rc "$out")"; }
printf '%s\n' "$out"
deployed "$REL" || fail "release not in deployed state"
n=0; for x in "$NS" $TARGETS; do n=$((n + $(kubectl get all -n "$x" --no-headers 2>/dev/null | wc -l))); done
echo "  created $n objects"
[[ "$n" -gt 0 ]] || fail "install produced no objects"

# ---- 2. Upgrade the PR chart in place (upgrade code path) ----
# Same values on purpose: a no-change upgrade still re-renders and re-applies
# (new revision, STATUS deployed). Forcing a value change is unsafe — a strict
# root-closed schema (e.g. br-sfn) rejects an injected podAnnotations key.
echo "===== [$CHART] upgrade (PR -> PR) ====="
out="$(helm upgrade "$REL" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} -n "$NS" --timeout "$TIMEOUT" 2>&1)" \
  && deployed "$REL" || { printf '%s\n' "$out"; fail "in-place upgrade failed" "$(readiness_rc "$out")"; }

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
  # ${#BASE_VARGS[@]} counts array elements, and each file contributes two of them
  # (-f and the path), so it reads double. Name them instead of counting.
  if [[ ${#BASE_VARGS[@]} -eq 0 ]]; then
    echo "  baseline values: none on origin/main — installing the baseline with chart defaults"
  else
    echo "  baseline values (from origin/main):"
    printf '    %s\n' "${BASE_VARGS[@]}" | grep -v '^    -f$'
  fi

  # Same retry the PR chart's build gets above: a dependency fetch is network
  # flaky, and the baseline half has no more business failing the run for that
  # than the PR half does.
  helm dependency build "$BASE_DIR" >/dev/null 2>&1 \
    || helm dependency update "$BASE_DIR" >/dev/null 2>&1 \
    || fail "baseline dependency build from origin/main failed, so the upgrade path went untested"

  # The baseline can pin a namespace the PR chart no longer renders, and TARGETS was
  # derived from the PR chart alone. Its resources would then land in a namespace
  # nobody created, the baseline install would fail, and the upgrade check would be
  # skipped as "probably unrelated" — the same masking this phase keeps running into.
  # Both installs share $TARGETS, so it holds the union and cleanup still sees them all.
  BASE_TARGETS="$(render_targets "$BASE_DIR" base | tr '\n' ' ')"
  for t in $BASE_TARGETS; do
    case " $TARGETS " in *" $t "*) ;; *) TARGETS="${TARGETS:+$TARGETS }$t" ;; esac
  done
  [[ -n "$BASE_TARGETS" ]] && echo "  baseline namespaces: $BASE_TARGETS"

  # A baseline that cannot install is never "unrelated": it is this chart at
  # origin/main, and the leg that would have caught an immutable-field or
  # namespace break does not run without it. Swallowing it reported OK while
  # proving only the install arm, after burning the whole --wait timeout on the
  # install it swallowed. A chart genuinely broken on main belongs in
  # .github/configs/helm-install-test-allow-failure.txt, which the HINT below
  # names, not in a message nobody reads.
  #
  # The two ways the baseline can fail are reported apart. `helm install` exiting
  # non-zero and a release that installed but never reached `deployed` (a hook
  # still running, a --wait race) need different output: printing helm's own
  # SUCCESS text under "the install failed" sends the next reader to the wrong
  # place.
  if ! base_out="$(do_install "${REL}-base" "$BASE_DIR" base 2>&1)"; then
    printf '%s\n' "$base_out" | tail -20 | sed 's/^/    /'
    fail "baseline install from origin/main failed, so the upgrade path went untested" "$(readiness_rc "$base_out")"
  fi
  if ! deployed "${REL}-base"; then
    helm status "${REL}-base" -n "$NS" 2>&1 | tail -20 | sed 's/^/    /'
    fail "baseline install from origin/main reported success but the release never reached deployed, so the upgrade path went untested"
  fi
  out="$(helm upgrade "${REL}-base" "$CHART_DIR" ${VARGS[@]+"${VARGS[@]}"} ${HOOKS[@]+"${HOOKS[@]}"} ${WAIT[@]+"${WAIT[@]}"} -n "$NS" --timeout "$TIMEOUT" 2>&1)" \
    && deployed "${REL}-base" || { printf '%s\n' "$out"; fail "upgrade from origin/main failed (immutable-field break?)" "$(readiness_rc "$out")"; }
  echo "  origin/main -> PR upgrade OK"
else
  echo "  (new chart — not on origin/main; skipping baseline upgrade)"
fi

echo "===== [$CHART] OK ====="
cleanup
