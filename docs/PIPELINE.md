# OrderHub CI/CD Pipeline Manual (`PIPELINE.md`)

This document describes how the automated GitHub Actions pipeline works, how each test stage functions, how environment promotion occurs, and how to operate and roll back deployments.

---

## 1. Pipeline Overview & Architecture

The pipeline automates post-commit verification and deployment with deterministic GitHub Actions workflows:

```
Developer pushes/merges to `uat`
            ↓
  GitHub Actions (on: push → uat)
            ↓
  ┌───────────────────────────────────────────────┐
  │ 1. Unit Tests & Lint (ruff + pytest unit)     │
  │ 2. Edge-Case Tests (pytest edge)              │  (Parallel CI Jobs)
  │ 3. Integration Tests (pytest integration)     │
  └───────────────────────────────────────────────┘
            ↓ All Green?
       NO → Pipeline aborts, failure notification sent, production untouched.
      YES ↓
  [deploy-uat] (GitHub Environment: uat)
    - scripts/deploy.sh uat
    - scripts/smoke_test.sh ${{ vars.APP_URL }}
            ↓
  [e2e-uat-tests] (GitHub Environment: uat)
    - Automated E2E feature journey tests against deployed UAT
            ↓ (All E2E Journeys Green)
  [promote-to-production] (GitHub Environment: production, REQUIRED REVIEWER Gate)
    - Manual approval in GitHub Actions UI
    - Fast-forward push: git push origin ${{ github.sha }}:refs/heads/production
      (Fails loudly if not a clean fast-forward)
    - scripts/deploy.sh production
    - scripts/smoke_test.sh ${{ vars.APP_URL }}
    - Auto-rollback on smoke failure: scripts/rollback.sh production <previous_sha>
            ↓
  [notify] (if: always())
    - scripts/notify.sh <status> <message>
```

---

## 2. Local Testing (Single Command)

All tests can be executed locally with a single command:

```bash
# Run all 19 test cases across all suites
python -m pytest tests/

# Run individual test suites
python -m pytest tests/unit -m unit
python -m pytest tests/edge -m edge
python -m pytest tests/integration -m integration
```

### Edge-Case Testing & Failure Gate
The edge-case suite under `tests/edge/test_edge_cases.py` validates:
- Empty, null, and missing parameters.
- Boundary conditions (0% and 100% discount, zero quantity).
- Max input size / payload truncation.
- Unicode and SQL/XSS injection patterns.
- Timezone and leap-year boundaries.
- External payment gateway timeouts (mocked).
- **Intentional Failure Gate:** A test gated behind `FAIL_GATE=true` allows verifying that CI blocks bad code:
  ```bash
  python -c "import os, pytest; os.environ['FAIL_GATE']='true'; pytest.main(['tests/edge/test_edge_cases.py', '-k', 'test_intentional_failure_gate'])"
  ```

---

## 3. Promotion & Fast-Forward Guarantee

1. **Promote the Same Commit:** The pipeline never creates a merge commit when promoting to production. It pushes the exact, tested commit SHA (`${{ github.sha }}`) to `refs/heads/production`.
2. **Fast-Forward Only:** If `production` has diverged, the promotion step **fails loudly** and refuses to force-push.
3. **Approval Gate:** The `promote-to-production` job is bound to the `production` GitHub Environment. GitHub Actions pauses execution until an authorized reviewer approves the deployment.

---

## 4. Deployment & Rollback Operations

### Automated Rollback
If the production deployment completes but the subsequent smoke test (`scripts/smoke_test.sh`) fails:
1. The step `Auto-Rollback on Smoke Test Failure` activates automatically.
2. It fetches the previously deployed commit SHA (`steps.prev_sha.outputs.sha`).
3. It executes `scripts/rollback.sh production <previous_sha>`.
4. The final `notify` step dispatches a failure alert.

### Manual Rollback (`rollback.yml`)
If a release needs to be rolled back manually:
1. Navigate to **Actions → Manual Rollback** in the GitHub repository.
2. Click **Run workflow**.
3. Select the environment (`uat` or `production`).
4. Enter the known-good commit SHA or release tag.
5. Click **Run workflow**.
