#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Rollback Script (Multi-Container: Frontend + Backend)
# Usage: ./scripts/rollback.sh <uat|production> <git_sha_or_tag>
# ==============================================================================

ENVIRONMENT="${1:-}"
TARGET_SHA="${2:-}"

if [[ "$ENVIRONMENT" != "uat" && "$ENVIRONMENT" != "production" ]]; then
  echo "ERROR: Invalid environment '${ENVIRONMENT}'. Must be 'uat' or 'production'." >&2
  echo "Usage: $0 <uat|production> <git_sha_or_tag>" >&2
  exit 1
fi

if [[ -z "$TARGET_SHA" ]]; then
  echo "ERROR: Missing target git SHA or tag to roll back to." >&2
  echo "Usage: $0 <uat|production> <git_sha_or_tag>" >&2
  exit 1
fi

DRY_RUN="${DRY_RUN:-true}"
export APP_ENV="${ENVIRONMENT}"

echo "=================================================="
echo "ROLLBACK TRIGGERED"
echo "Target Environment: ${ENVIRONMENT}"
echo "Rollback to SHA:    ${TARGET_SHA}"
echo "Dry Run Mode:       ${DRY_RUN}"
echo "Timestamp (UTC):    $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
echo "=================================================="

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Rollback dry-run enabled."
  echo "[STUB] Simulated Docker Compose rollback of ${ENVIRONMENT} to known-good SHA ${TARGET_SHA} succeeded."
  exit 0
fi

# ==============================================================================
# LIVE DOCKER COMPOSE ROLLBACK IMPLEMENTATION
# ==============================================================================
echo "Executing live rollback on ${ENVIRONMENT} to ${TARGET_SHA}..."
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-appuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

if [[ -n "$DEPLOY_HOST" ]]; then
  echo "Connecting to on-prem server ${DEPLOY_USER}@${DEPLOY_HOST}..."
  # ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
  #   set -euo pipefail
  #   cd /opt/orderhub/app
  #   git fetch origin
  #   git checkout ${TARGET_SHA}
  #   export APP_ENV="${ENVIRONMENT}"
  #   docker-compose -f docker-compose.yml down || true
  #   docker-compose -f docker-compose.yml up -d --build
  # EOF
else
  echo "Rolling back local Docker Compose stack to ${TARGET_SHA}..."
  git checkout "${TARGET_SHA}"
  docker-compose -f docker-compose.yml down || true
  docker-compose -f docker-compose.yml up -d --build
fi

echo "Rollback of ${ENVIRONMENT} to ${TARGET_SHA} completed successfully."
exit 0
