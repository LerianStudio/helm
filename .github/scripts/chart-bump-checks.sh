#!/usr/bin/env bash
# Prints the CI verdict of a bot chart bump: green, pending or failed (one word, last line).
# Used by chart-bump-merge.yml twice: to decide, and again right before the merge.
#
# env: GH_TOKEN REPO PR_NUMBER REQUIRED_CHECKS IGNORED_CHECKS NON_BLOCKING_PENDING
#   REQUIRED_CHECKS       newline list; each must exist and pass
#   IGNORED_CHECKS        JSON list; left out entirely
#   NON_BLOCKING_PENDING  JSON list; may still be pending, but a failure blocks
set -uo pipefail

checks=""
for _ in 1 2 3; do
  checks=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,bucket 2>/dev/null) && [ -n "$checks" ] && break
  checks=""
  sleep 5
done
if [ -z "$checks" ]; then
  echo "::warning::Could not read the checks of #${PR_NUMBER}"
  echo pending
  exit 0
fi

checks=$(jq -c --argjson ignored "$IGNORED_CHECKS" 'map(select(.name as $n | $ignored | index($n) | not))' <<<"$checks")
failed=$(jq -r 'map(select(.bucket == "fail" or .bucket == "cancel")) | .[].name' <<<"$checks")
if [ -n "$failed" ]; then
  echo "Checks failed: $(paste -sd ',' - <<<"$failed")" >&2
  echo failed
  exit 0
fi
missing=""
while IFS= read -r name; do
  [ -z "$name" ] && continue
  jq -e --arg n "$name" 'any(.[]; .name == $n and .bucket == "pass")' <<<"$checks" >/dev/null || missing+="${name}; "
done <<<"$REQUIRED_CHECKS"
pending=$(jq -r --argjson nb "$NON_BLOCKING_PENDING" \
  'map(select(.bucket == "pending" and (.name as $n | $nb | index($n) | not))) | .[].name' <<<"$checks" | paste -sd ',' -)
if [ -n "$missing" ] || [ -n "$pending" ]; then
  echo "Not yet. Required not passed: ${missing:-none}. Pending: ${pending:-none}" >&2
  echo pending
  exit 0
fi
echo "All checks green." >&2
echo green
