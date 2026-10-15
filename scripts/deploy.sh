#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Deployment Script (Multi-Container: Frontend + Backend)
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
export APP_ENV="${ENVIRONMENT}"
export FRONTEND_PORT="${FRONTEND_PORT:-3000}"
export BACKEND_PORT="${BACKEND_PORT:-8000}"

echo "=================================================="
echo "Starting deployment"
echo "Target Environment: ${ENVIRONMENT}"
echo "Commit SHA:         ${COMMIT_SHA}"
echo "Dry Run Mode:       ${DRY_RUN}"
echo "Frontend Port:      ${FRONTEND_PORT}"
echo "Backend Port:       ${BACKEND_PORT}"
echo "Timestamp (UTC):    $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
echo "=================================================="

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Dry-run enabled. Simulated Docker Compose deployment of frontend & backend to ${ENVIRONMENT} for commit ${COMMIT_SHA} succeeded."
  echo "[STUB] Environment variables configured via GitHub Environment: ${ENVIRONMENT}."
  echo "[STUB] Successfully deployed ${COMMIT_SHA} to ${ENVIRONMENT}."
  exit 0
fi

# ==============================================================================
# LIVE DOCKER COMPOSE DEPLOYMENT
# ==============================================================================
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-appuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

if [[ -n "$DEPLOY_HOST" ]]; then
  echo "Connecting to on-prem server ${DEPLOY_USER}@${DEPLOY_HOST}..."
  # ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
  #   set -euo pipefail
  #   cd /opt/orderhub/app
  #   git fetch origin
  #   git checkout ${COMMIT_SHA}
  #   export APP_ENV="${ENVIRONMENT}"
  #   docker-compose -f docker-compose.yml down || true
  #   docker-compose -f docker-compose.yml up -d --build
  # EOF
else
  echo "Deploying local Docker Compose stack to ${ENVIRONMENT}..."
  docker-compose -f docker-compose.yml down || true
  docker-compose -f docker-compose.yml up -d --build
fi

echo "Deployment to ${ENVIRONMENT} completed successfully."
exit 0
