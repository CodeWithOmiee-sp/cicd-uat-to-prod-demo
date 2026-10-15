#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Smoke Test Script (Dual Container: Backend + Frontend)
# Usage: ./scripts/smoke_test.sh <backend_url> [frontend_url]
# ==============================================================================

BACKEND_URL="${1:-}"
FRONTEND_URL="${2:-${FRONTEND_URL:-}}"

if [[ -z "$BACKEND_URL" ]]; then
  echo "ERROR: Missing base URL argument." >&2
  echo "Usage: $0 <backend_url> [frontend_url]" >&2
  exit 1
fi

BACKEND_HEALTH_URL="${BACKEND_URL%/}/api/health"
MAX_ATTEMPTS=5
RETRY_DELAY=5

echo "=================================================="
echo "Smoke Test: Verifying multi-container service health"
echo "Backend Endpoint:  ${BACKEND_HEALTH_URL}"
if [[ -n "$FRONTEND_URL" ]]; then
  echo "Frontend Endpoint: ${FRONTEND_URL%/}/healthz"
fi
echo "Max Attempts:      ${MAX_ATTEMPTS}"
echo "Retry Delay:       ${RETRY_DELAY}s"
echo "=================================================="

# Test Backend Container
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "[Backend Attempt ${attempt}/${MAX_ATTEMPTS}] Pinging backend health endpoint..."
  
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${BACKEND_HEALTH_URL}" 2>/dev/null || echo "000")
  
  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "SUCCESS: Backend endpoint returned HTTP 200 OK."
    break
  fi
  
  echo "WARNING: Backend health check returned HTTP ${HTTP_STATUS}. Retrying in ${RETRY_DELAY}s..."
  if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
    sleep "$RETRY_DELAY"
  else
    echo "ERROR: Backend smoke test failed. Health check did not return HTTP 200 within ${MAX_ATTEMPTS} attempts." >&2
    exit 1
  fi
done

# Test Frontend Container (if URL provided)
if [[ -n "$FRONTEND_URL" ]]; then
  FRONTEND_HEALTH_URL="${FRONTEND_URL%/}/healthz"
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo "[Frontend Attempt ${attempt}/${MAX_ATTEMPTS}] Pinging frontend health endpoint..."
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${FRONTEND_HEALTH_URL}" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_STATUS" == "200" ]]; then
      echo "SUCCESS: Frontend endpoint returned HTTP 200 OK."
      break
    fi
    
    echo "WARNING: Frontend health check returned HTTP ${HTTP_STATUS}. Retrying in ${RETRY_DELAY}s..."
    if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
      sleep "$RETRY_DELAY"
    else
      echo "ERROR: Frontend smoke test failed. Health check did not return HTTP 200 within ${MAX_ATTEMPTS} attempts." >&2
      exit 1
    fi
  done
fi

echo "Multi-container smoke test passed successfully."
exit 0
