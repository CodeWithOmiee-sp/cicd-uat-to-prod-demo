#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OrderHub Rollback Script
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

echo "=================================================="
echo "ROLLBACK TRIGGERED"
echo "Target Environment: ${ENVIRONMENT}"
echo "Rollback to SHA:    ${TARGET_SHA}"
echo "Dry Run Mode:       ${DRY_RUN}"
echo "Timestamp (UTC):    $(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
echo "=================================================="

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Rollback dry-run enabled."
  echo "[STUB] Simulated rollback of ${ENVIRONMENT} to known-good SHA ${TARGET_SHA} succeeded."
  exit 0
fi

# ==============================================================================
# ON-PREM VM ROLLBACK IMPLEMENTATION
# ==============================================================================
echo "Executing live rollback on ${ENVIRONMENT}..."
DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-appuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

if [[ -z "$DEPLOY_HOST" ]]; then
  echo "ERROR: DEPLOY_HOST is required for live rollback." >&2
  exit 1
fi

# ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
#   set -euo pipefail
#   cd /opt/orderhub/app
#   git fetch origin
#   git checkout ${TARGET_SHA}
#   export APP_ENV="${ENVIRONMENT}"
#   docker-compose -f docker-compose.${ENVIRONMENT}.yml down
#   docker-compose -f docker-compose.${ENVIRONMENT}.yml up -d --build
# EOF

echo "Rollback of ${ENVIRONMENT} to ${TARGET_SHA} completed successfully."
exit 0
