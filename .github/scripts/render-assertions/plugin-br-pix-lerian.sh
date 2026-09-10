#!/usr/bin/env bash
#
# Render assertions for charts/plugin-br-pix-lerian.
#
# These are regression tests, not a lint: each one failed against a real defect
# in this chart and would fail again if the fix were reverted. They read only
# `helm template` output, so they need helm and nothing else -- no cluster, no
# YAML library, no Python.
#
# Run from the repository root:
#
#   .github/scripts/render-assertions/plugin-br-pix-lerian.sh
#
# Any assertion that fails prints the offending value and the script exits 1.

set -euo pipefail

CHART_DIR="charts/plugin-br-pix-lerian"
FIXTURE=".github/configs/helm-render-values/plugin-br-pix-lerian.yaml"

if [[ ! -d "$CHART_DIR" ]]; then
  echo "run me from the repository root (no $CHART_DIR here)" >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }
head2() { printf '\n== %s\n' "$1"; }

APP_VERSION="$(awk -F'"' '/^appVersion:/ {print $2}' "$CHART_DIR/Chart.yaml")"
CHART_VERSION="$(awk '/^version:/ {print $2}' "$CHART_DIR/Chart.yaml")"

# ---------------------------------------------------------------------------
# Renders under test.
#
# charts/*/charts/ is gitignored, so the subchart archives may be absent on a
# fresh clone. Build them once, and only when they are missing -- the render
# gate that runs before this in CI already builds them, and repeating a network
# fetch would add a flake for nothing.
# ---------------------------------------------------------------------------
if [[ ! -d "$CHART_DIR/charts" ]] || [[ -z "$(ls -A "$CHART_DIR/charts" 2>/dev/null)" ]]; then
  helm dependency build "$CHART_DIR" > /dev/null
fi

helm template review "$CHART_DIR" --namespace review              > "$WORK/default.yaml"
helm template review "$CHART_DIR" --namespace review \
  -f "$CHART_DIR/values-template.yaml"                            > "$WORK/production.yaml"
helm template review "$CHART_DIR" --namespace review \
  -f "$FIXTURE"                                                   > "$WORK/fixture.yaml"

# ---------------------------------------------------------------------------
# 1-3. `default` must not swallow an explicit 0.
# ---------------------------------------------------------------------------
head2 "explicit zeros survive the render (fixture sets four of them on spi)"

spi_job() { awk '/templates\/_migrations.tpl/{f=0} /plugin-br-pix-lerian-spi-migrations/{f=1} f' "$WORK/fixture.yaml"; }

if grep -qE '^  ttlSecondsAfterFinished: 0$' "$WORK/fixture.yaml"; then
  ok "migrations.ttlSecondsAfterFinished: 0 renders as 0"
else
  bad "migrations.ttlSecondsAfterFinished: 0 did not render as 0"
  grep -n 'ttlSecondsAfterFinished' "$WORK/fixture.yaml" >&2 || true
fi

if grep -qE '^  backoffLimit: 0$' "$WORK/fixture.yaml"; then
  ok "migrations.backoffLimit: 0 renders as 0"
else
  bad "migrations.backoffLimit: 0 did not render as 0"
  grep -n 'backoffLimit' "$WORK/fixture.yaml" >&2 || true
fi

zero_probes="$(grep -cE '^ +initialDelaySeconds: 0$' "$WORK/fixture.yaml" || true)"
if [[ "$zero_probes" == "2" ]]; then
  ok "readiness/liveness initialDelaySeconds: 0 renders as 0 (both probes)"
else
  bad "expected 2 probes at initialDelaySeconds: 0, found $zero_probes"
fi

# ---------------------------------------------------------------------------
# 4. spec.ingressClassName must stay a string.
# ---------------------------------------------------------------------------
head2 "ingressClassName is a string even when the class name looks numeric"

classnames="$(grep -E '^ +ingressClassName:' "$WORK/fixture.yaml" || true)"
if [[ -z "$classnames" ]]; then
  bad "fixture rendered no ingressClassName at all"
elif grep -qvE '^ +ingressClassName: "[^"]*"$' <<< "$classnames"; then
  bad "an ingressClassName rendered unquoted:"
  grep -vE '^ +ingressClassName: "[^"]*"$' <<< "$classnames" >&2
else
  ok "all $(wc -l <<< "$classnames" | tr -d ' ') ingressClassName values are quoted"
fi

# ---------------------------------------------------------------------------
# 5. No duplicate names inside one container's env list.
# ---------------------------------------------------------------------------
head2 "containers[].env has no duplicate names"

dupes="$(awk '
  /^---/                       { doc = NR; container = ""; delete seen; next }
  /^ {8}- name: /              { container = $3; inenv = 0; next }
  /^ {10}env:[[:space:]]*$/    { inenv = 1; next }
  /^ {10}[a-zA-Z]/             { inenv = 0 }
  inenv && /^ {12}- name: /    {
                                 key = doc "|" container "|" $3
                                 if (key in seen) print "duplicate " $3 " in container " container " (document at line " doc ")"
                                 seen[key] = 1
                               }
' "$WORK/fixture.yaml" "$WORK/default.yaml" "$WORK/production.yaml" || true)"

if [[ -n "$dupes" ]]; then
  bad "duplicate env names found:"
  printf '%s\n' "$dupes" >&2
else
  ok "no duplicate env names in the default, production or fixture render"
fi

# ---------------------------------------------------------------------------
# 6. Every hook Job satisfies Pod Security Admission `restricted`.
# ---------------------------------------------------------------------------
head2 "bootstrap and migration Jobs satisfy Pod Security \`restricted\`"

# A Job document is restricted-compliant when the pod sets seccompProfile
# RuntimeDefault and EVERY container and initContainer sets runAsNonRoot,
# allowPrivilegeEscalation: false and capabilities.drop: ALL. Containers are
# counted only inside the containers:/initContainers: blocks, so the volumes:
# list below them is not mistaken for one.
for render in default production fixture; do
  report="$(awk -v render="$render" '
    function flush() {
      if (kind != "Job" || name == "") return
      if (!podSeccomp) printf "%s: Job %s has no pod-level seccompProfile RuntimeDefault\n", render, name
      if (containers == 0) printf "%s: Job %s renders no container\n", render, name
      if (nonroot   < containers) printf "%s: Job %s: runAsNonRoot on %d of %d containers\n", render, name, nonroot, containers
      if (noescal   < containers) printf "%s: Job %s: allowPrivilegeEscalation:false on %d of %d containers\n", render, name, noescal, containers
      if (dropall   < containers) printf "%s: Job %s: capabilities.drop ALL on %d of %d containers\n", render, name, dropall, containers
      jobs++
      totalContainers += containers
    }
    /^---/ { flush(); kind=""; name=""; podSeccomp=0; containers=0; nonroot=0; noescal=0; dropall=0; inList=0; podLevel=0; next }
    /^kind: Job$/                     { kind="Job"; next }
    /^  name: / && name == ""         { name=$2; next }
    /^      securityContext:$/        { podLevel=1; inList=0; next }
    /^      (init)?[Cc]ontainers:$/   { inList=1; podLevel=0; next }
    /^      [a-zA-Z]/                 { inList=0; podLevel=0 }
    podLevel && /type: RuntimeDefault/ { podSeccomp=1 }
    podLevel && /runAsNonRoot: true/   { podNonRoot=1 }
    inList && /^        - name: /      { containers++; if (podNonRoot) nonroot++ }
    inList && /runAsNonRoot: true/     { if (!podNonRoot) nonroot++ }
    inList && /allowPrivilegeEscalation: false/ { noescal++ }
    inList && /^ +- ALL$/              { dropall++ }
    inList && /drop: \["ALL"\]/        { dropall++ }
    END { flush(); printf "COUNTS %d %d\n", jobs, totalContainers }
  ' "$WORK/$render.yaml")"

  counts="$(grep '^COUNTS ' <<< "$report")"
  problems="$(grep -v '^COUNTS ' <<< "$report" || true)"
  set -- $counts
  if [[ "$2" == "0" ]]; then
    ok "$render render: no Job to check"
  elif [[ -n "$problems" ]]; then
    bad "$render render: Pod Security \`restricted\` violations:"
    printf '%s\n' "$problems" >&2
  else
    ok "$render render: all $2 Job(s) and $3 container(s) are restricted-compliant"
  fi
done

# ---------------------------------------------------------------------------
# 7. values-template.yaml is a production posture.
# ---------------------------------------------------------------------------
head2 "values-template.yaml presents a production posture"

if grep -qE '^ +- name: ENV_NAME$' -A1 "$WORK/production.yaml" 2>/dev/null; then :; fi
devs="$(grep -E '^  ENV_NAME: ' "$WORK/production.yaml" | grep -v 'production' || true)"
if [[ -n "$devs" ]]; then
  bad "a ConfigMap in the production render carries a non-production ENV_NAME:"
  printf '%s\n' "$devs" >&2
else
  ok "no ConfigMap in the production render carries a non-production ENV_NAME"
fi

for proxy in dict-proxy cob-proxy; do
  if grep -q "name: plugin-br-pix-lerian-$proxy$" "$WORK/production.yaml"; then
    bad "values-template.yaml still enables $proxy, which serves no business route in this release"
  else
    ok "values-template.yaml ships $proxy disabled"
  fi
done

# ---------------------------------------------------------------------------
# 8. The chart carries only variables the pinned application reads.
# ---------------------------------------------------------------------------
head2 "pixauto's auth contract matches appVersion $APP_VERSION"

# Scope: the configuration surface the chart ships and renders. The CHANGELOG
# names both variables on purpose, to explain why appVersion moved.
auth_surface=("$CHART_DIR/templates" "$CHART_DIR/values.yaml" "$CHART_DIR/values-template.yaml" "$CHART_DIR/values.schema.json" "$CHART_DIR/README.md")
if grep -rq 'AUTH_JWT_VERIFY_CERT\|AUTH_JWT_ISSUER' "${auth_surface[@]}"; then
  bad "the chart still ships AUTH_JWT_VERIFY_CERT / AUTH_JWT_ISSUER, which $APP_VERSION does not read"
  grep -rn 'AUTH_JWT_VERIFY_CERT\|AUTH_JWT_ISSUER' "${auth_surface[@]}" >&2
else
  ok "no AUTH_JWT_VERIFY_CERT / AUTH_JWT_ISSUER anywhere in the chart"
fi

# ---------------------------------------------------------------------------
# 9. Untagged workloads inherit appVersion.
# ---------------------------------------------------------------------------
head2 "every workload image resolves to appVersion $APP_VERSION"

offenders="$(grep -E '^ +image: ghcr.io/lerianstudio/plugin-br-pix-lerian-' "$WORK/fixture.yaml" \
  | grep -v ":$APP_VERSION\$" || true)"
count="$(grep -cE '^ +image: ghcr.io/lerianstudio/plugin-br-pix-lerian-' "$WORK/fixture.yaml" || true)"
if [[ -n "$offenders" ]]; then
  bad "an image did not inherit appVersion:"
  printf '%s\n' "$offenders" >&2
else
  ok "all $count plugin-br-pix-lerian image references are pinned to $APP_VERSION"
fi

# ---------------------------------------------------------------------------
# 13. The retired credentials key is rejected, and by name.
# ---------------------------------------------------------------------------
head2 "global.externalPostgresDefinitions credentials key migration"

cat > "$WORK/legacy.yaml" <<'YAML'
global:
  externalPostgresDefinitions:
    pixswitchCredentials:
      username: "pixswitch"
      password: "assertion-only"
YAML
cat > "$WORK/renamed.yaml" <<'YAML'
global:
  externalPostgresDefinitions:
    pixLerianCredentials:
      username: "pixswitch"
      password: "assertion-only"
YAML

if helm template review "$CHART_DIR" --namespace review -f "$WORK/legacy.yaml" \
     > /dev/null 2> "$WORK/legacy.err"; then
  bad "the retired pixswitchCredentials key was accepted"
elif grep -q "/global/externalPostgresDefinitions/pixswitchCredentials" "$WORK/legacy.err"; then
  ok "pixswitchCredentials is rejected, and the error names that exact path"
else
  bad "pixswitchCredentials is rejected, but the error does not name it:"
  cat "$WORK/legacy.err" >&2
fi

if helm template review "$CHART_DIR" --namespace review -f "$WORK/renamed.yaml" > /dev/null 2>&1; then
  ok "pixLerianCredentials renders"
else
  bad "pixLerianCredentials failed to render"
  helm template review "$CHART_DIR" --namespace review -f "$WORK/renamed.yaml" >/dev/null || true
fi

# ---------------------------------------------------------------------------
# 10. The chart still packages.
# ---------------------------------------------------------------------------
head2 "chart $CHART_VERSION packages"

if helm package "$CHART_DIR" --destination "$WORK" > /dev/null; then
  ok "helm package produced plugin-br-pix-lerian-helm-$CHART_VERSION.tgz"
else
  bad "helm package failed"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
