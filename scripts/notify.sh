#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Pipeline Notification Script
# Usage: ./scripts/notify.sh <status> <message>
# Note: Always exits 0 to prevent notification failures from breaking the pipeline.
# ==============================================================================

STATUS="${1:-INFO}"
MESSAGE="${2:-No message provided}"
WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'local')}"
REF_NAME="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"

echo "=================================================="
echo "[PIPELINE NOTIFICATION]"
echo "Status:  ${STATUS}"
echo "Message: ${MESSAGE}"
echo "Branch:  ${REF_NAME}"
echo "Commit:  ${COMMIT_SHA}"
echo "=================================================="

if [[ -n "$WEBHOOK_URL" ]]; then
  echo "Dispatching notification to Slack webhook..."
  PAYLOAD=$(cat <<EOF
{
  "text": "📊 *OrderHub Pipeline Update*\n• *Status:* ${STATUS}\n• *Message:* ${MESSAGE}\n• *Branch:* \`${REF_NAME}\`\n• *Commit:* \`${COMMIT_SHA}\`"
}
EOF
)
  curl -s -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$WEBHOOK_URL" > /dev/null 2>&1 || true
  echo "Slack webhook dispatched."
else
  echo "No SLACK_WEBHOOK_URL configured. Notification logged to console only."
fi

exit 0
