#!/usr/bin/env bash
# Sends the Severino PR review ticket for a bot chart bump, once per pull request.
#
# Same text helm-update-chart.yml sends, which Severino parses into the ticket. Labels the
# pull request TICKET_LABEL (dedupe across runs) and REVIEW_LABEL (keeps it off auto-merge).
# Used by chart-bump-automerge.yml (not routine) and chart-bump-merge.yml (CI failed).
#
# env: GH_TOKEN REPO PR_NUMBER SLACK_BOT_TOKEN BOT_MENTION SLACK_CHANNEL TICKET_LABEL REVIEW_LABEL
set -euo pipefail

pr=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json state,url,headRefName,labels)
if ! jq -e '.state == "OPEN"' <<<"$pr" >/dev/null; then
  echo "Pull request is no longer open; no ticket"
  exit 0
fi
if jq -e --arg l "$TICKET_LABEL" 'any(.labels[]; .name == $l)' <<<"$pr" >/dev/null; then
  echo "Severino ticket already sent for this pull request"
  exit 0
fi
if [ -z "${SLACK_BOT_TOKEN:-}" ] || [ -z "${BOT_MENTION:-}" ] || [ -z "${SLACK_CHANNEL:-}" ]; then
  echo "::error::SLACK_BOT_TOKEN_HELM, SLACK_BOT_SEVERINO or vars.SLACK_CHANNEL_DEVOPS is empty; the review ticket was not sent"
  exit 1
fi

PR_URL=$(jq -r .url <<<"$pr")
# update/<chart>/<ref>-<timestamp>, as helm-update-chart.yml names it.
CHART=$(jq -r .headRefName <<<"$pr" | cut -d/ -f2)
payload=$(jq -n --arg channel "$SLACK_CHANNEL" \
  --arg text "<@${BOT_MENTION}> helm chart PR review | ${PR_URL} | Chart: ${CHART}" \
  '{channel: $channel, text: $text}')
response=$(curl -s -X POST \
  -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
  -H "Content-type: application/json; charset=utf-8" \
  --data "$payload" \
  "https://slack.com/api/chat.postMessage")
if ! jq -e '.ok == true' <<<"$response" >/dev/null; then
  echo "::error::Failed to send the Severino message"
  jq . <<<"$response"
  exit 1
fi
echo "Severino ticket sent for ${PR_URL}"
gh api "repos/${REPO}/issues/${PR_NUMBER}/labels" -f "labels[]=${TICKET_LABEL}" -f "labels[]=${REVIEW_LABEL}" >/dev/null \
  || echo "::warning::Ticket sent, but the labels could not be added; a later run may send another or still auto-merge"
