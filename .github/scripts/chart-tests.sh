#!/usr/bin/env bash
# chart-tests.sh — run a chart's offline regression suite, if it has one.
# Every charts/<chart>/tests/test_*.py is run as a script after the chart's
# dependencies are built; its exit code is the verdict, so a unittest module and a
# plain script with its own main() both work. A chart opts in by adding the
# directory: there is no per-chart workflow to write or keep in step with this gate.
#
# Usage: chart-tests.sh <chart-dir>
set -uo pipefail

CHART_DIR="$1"
CHART="$(basename "$CHART_DIR")"

if ! compgen -G "$CHART_DIR/tests/test_*.py" >/dev/null; then
  echo "::notice::[$CHART] no tests/ suite — skipping chart tests."
  exit 0
fi

echo "===== [$CHART] dependency build ====="
# Same registration the install script does: every https:// dependency repo must
# be known to helm before `helm dependency build` (oci:// and file:// need none).
depn=0
while IFS= read -r repo_url; do
  [[ -z "$repo_url" ]] && continue
  helm repo add "dep${depn}" "$repo_url" >/dev/null 2>&1 || true
  depn=$((depn + 1))
done < <(grep -E 'repository:[[:space:]]*"?https?://' "$CHART_DIR/Chart.yaml" | grep -Eo 'https?://[^"[:space:]]+' | sort -u)
[[ "$depn" -gt 0 ]] && helm repo update >/dev/null 2>&1
db_out="$(helm dependency build "$CHART_DIR" 2>&1)" \
  || db_out="$(helm dependency update "$CHART_DIR" 2>&1)" \
  || { echo "$db_out" | tail -8 | sed 's/^/    /'; echo "::error::[$CHART] helm dependency build failed"; exit 1; }

rc=0
for test in "$CHART_DIR"/tests/test_*.py; do
  echo "===== [$CHART] $(basename "$test") ====="
  if ! python3 "$test"; then
    echo "::error::[$CHART] $(basename "$test") failed"
    rc=1
  fi
done
exit "$rc"
