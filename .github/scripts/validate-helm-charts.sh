#!/bin/bash
# Validate Helm charts for kubeVersion and other quality checks

set -e

ROOT="${1:-.}"
STRICT="${2:---strict}"

echo "🔍 Validating Helm charts..."
echo ""

# Find all Chart.yaml files
charts=$(find "$ROOT/charts" -name "Chart.yaml" -type f 2>/dev/null || true)
count=0
errors=0

for chart in $charts; do
    count=$((count + 1))
    chart_name=$(dirname "$chart" | xargs basename)
    
    # Check kubeVersion exists
    if ! grep -q "^kubeVersion:" "$chart"; then
        echo "❌ $chart_name: missing kubeVersion"
        errors=$((errors + 1))
    else
        echo "✓ $chart_name: kubeVersion present"
    fi
done

echo ""
echo "📊 Summary: $count charts validated"

if [ "$errors" -gt 0 ]; then
    echo "❌ $errors validation error(s) found"
    if [ "$STRICT" = "--strict" ]; then
        exit 1
    fi
else
    echo "✅ All charts valid"
    exit 0
fi
