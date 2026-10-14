#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Smoke Test Script
# Usage: ./scripts/smoke_test.sh <base_url>
# ==============================================================================

BASE_URL="${1:-}"

if [[ -z "$BASE_URL" ]]; then
  echo "ERROR: Missing base URL argument." >&2
  echo "Usage: $0 <base_url>" >&2
  exit 1
fi

HEALTH_URL="${BASE_URL%/}/api/health"
MAX_ATTEMPTS=5
RETRY_DELAY=5

echo "=================================================="
echo "Smoke Test: Verifying service health"
echo "Target Endpoint: ${HEALTH_URL}"
echo "Max Attempts:    ${MAX_ATTEMPTS}"
echo "Retry Delay:     ${RETRY_DELAY}s"
echo "=================================================="

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "[Attempt ${attempt}/${MAX_ATTEMPTS}] Pinging health endpoint..."
  
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${HEALTH_URL}" 2>/dev/null || echo "000")
  
  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "SUCCESS: Endpoint returned HTTP 200 OK."
    exit 0
  fi
  
  echo "WARNING: Health check returned HTTP ${HTTP_STATUS}. Retrying in ${RETRY_DELAY}s..."
  if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
    sleep "$RETRY_DELAY"
  fi
done

echo "ERROR: Smoke test failed. Health check did not return HTTP 200 within ${MAX_ATTEMPTS} attempts." >&2
exit 1
