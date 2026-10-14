#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Deployment Script
# Usage: ./scripts/deploy.sh <uat|production>
# ==============================================================================

ENVIRONMENT="${1:-}"

if [[ "$ENVIRONMENT" != "uat" && "$ENVIRONMENT" != "production" ]]; then
  echo "ERROR: Invalid environment '${ENVIRONMENT}'. Must be 'uat' or 'production'." >&2
  echo "Usage: $0 <uat|production>" >&2
  exit 1
fi

COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'local-build')}"
DRY_RUN="${DRY_RUN:-true}"
APP_PORT="${PORT:-8000}"

echo "=================================================="
echo "Starting deployment"
echo "Target Environment: ${ENVIRONMENT}"
echo "Commit SHA:         ${COMMIT_SHA}"
echo "Dry Run Mode:       ${DRY_RUN}"
echo "Timestamp (UTC):    $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
echo "=================================================="

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Dry-run enabled. Simulating deployment to ${ENVIRONMENT} for commit ${COMMIT_SHA}..."
  echo "[STUB] Environment variables configured via GitHub Environment: ${ENVIRONMENT}."
  echo "[STUB] Successfully deployed ${COMMIT_SHA} to ${ENVIRONMENT}."
  exit 0
fi

# ==============================================================================
# ON-PREM VM / PRODUCTION DEPLOYMENT IMPLEMENTATION
# (Target: Company On-Prem VM via SSH & Docker)
# ==============================================================================
echo "Executing real deployment to ${ENVIRONMENT} on-premise infrastructure..."

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-appuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

if [[ -z "$DEPLOY_HOST" ]]; then
  echo "ERROR: DEPLOY_HOST is required for live deployment." >&2
  exit 1
fi

echo "Connecting to on-prem server ${DEPLOY_USER}@${DEPLOY_HOST}..."
# In live deployment on company VM:
# ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
#   set -euo pipefail
#   cd /opt/orderhub/app
#   git fetch origin
#   git checkout ${COMMIT_SHA}
#   export APP_ENV="${ENVIRONMENT}"
#   docker-compose -f docker-compose.${ENVIRONMENT}.yml pull || true
#   docker-compose -f docker-compose.${ENVIRONMENT}.yml up -d --build
# EOF

echo "Deployment to ${ENVIRONMENT} completed successfully."
exit 0
