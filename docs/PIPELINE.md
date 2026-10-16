# OrderHub CI/CD Pipeline Manual (`PIPELINE.md`)

This document describes how the automated GitHub Actions pipeline works, how each test stage functions, how multi-container Docker orchestration operates, how environment promotion occurs, and how to operate and roll back deployments.

---

## 1. Pipeline Overview & Architecture

The pipeline automates post-commit verification and deployment with deterministic GitHub Actions workflows:

```
Developer pushes/merges to `uat`
            ↓
  GitHub Actions (on: push → uat)
            ↓
  ┌────────────────────────────────────────────────────────┐
  │ 1. Unit Tests & Lint (ruff + pytest unit)              │
  │ 2. Edge-Case Tests (pytest edge)                       │  (Parallel CI Jobs)
  │ 3. Integration Tests (pytest integration)              │
  │ 4. Docker Build Test (Dockerfile.backend + frontend)   │
  └────────────────────────────────────────────────────────┘
            ↓ All Green?
       NO → Pipeline aborts, failure notification sent, production untouched.
      YES ↓
  [deploy-uat] (GitHub Environment: uat)
    - scripts/deploy.sh uat (Docker Compose multi-container stack)
    - scripts/smoke_test.sh ${{ vars.APP_URL }} ${{ vars.FRONTEND_URL }}
            ↓
  [e2e-uat-tests] (GitHub Environment: uat)
    - Automated E2E feature user journey tests against deployed UAT
            ↓ (All E2E Journeys Green)
  [promote-to-production] (GitHub Environment: production, REQUIRED REVIEWER Gate)
    - Manual approval in GitHub Actions UI
    - Fast-forward push: git push origin ${{ github.sha }}:refs/heads/production
      (Fails loudly if not a clean fast-forward)
    - scripts/deploy.sh production (Docker Compose multi-container stack)
    - scripts/smoke_test.sh ${{ vars.APP_URL }} ${{ vars.FRONTEND_URL }}
    - Auto-rollback on smoke failure: scripts/rollback.sh production <previous_sha>
            ↓
  [notify] (if: always())
    - scripts/notify.sh <status> <message>
```

---

## 2. Multi-Container Docker Architecture

OrderHub runs as two isolated containers orchestrated via `docker-compose.yml`:
1. **Frontend Container (`Dockerfile.frontend`)**:
   - Lightweight Alpine Nginx web server.
   - Accepts build argument `ARG API_URL` to generate `/usr/share/nginx/html/config.js` (`window.__APP_CONFIG__.API_BASE_URL`).
   - Serves dashboard UI (`frontend/index.html`) on port `3000`.
   - **Dual-Mode Operation:** If `API_URL` is baked into the build, calls that explicit backend; otherwise falls back to local relative reverse-proxy (`/api/*` -> `http://backend:8000/api/*`).
   - Exposes `/healthz` for Nginx container health monitoring.
2. **Backend Container (`Dockerfile.backend`)**:
   - Python 3.11-slim runtime running FastAPI / Uvicorn on port `8000`.
   - Contains business logic and REST endpoints.
   - Exposes `/api/health` for container health monitoring.

### Building Frontend with Environment-Specific URLs:

```bash
# Build frontend targeting UAT backend
docker build --build-arg API_URL="https://uat-api.example.com" -f Dockerfile.frontend -t orderhub-frontend:uat .

# Build frontend targeting Production backend
docker build --build-arg API_URL="https://api.example.com" -f Dockerfile.frontend -t orderhub-frontend:prod .
```

### Running Multi-Container Stack Locally:

```bash
# Start both Frontend and Backend containers in background
docker compose up -d --build

# Check status of containers
docker compose ps

# Access Frontend Dashboard:
# http://localhost:3000

# Access Backend API / OpenAPI Docs:
# http://localhost:8000/docs
# http://localhost:8000/api/health

# Stop containers
docker compose down
```

---

## 3. Local Testing (Single Command)

All tests can be executed locally with a single command without Docker or external network dependencies:

```bash
# Run all 23 test cases across all suites
python -m pytest tests/

# Run individual test suites
python -m pytest tests/unit -m unit
python -m pytest tests/edge -m edge
python -m pytest tests/integration -m integration
python -m pytest tests/e2e -m e2e

# Run with Code Coverage & Branch Analysis (80% threshold)
python -m pytest --cov=app --cov-report=term-missing
```

### Code Coverage Gate (80% Threshold)
The pipeline enforces a strict **80% minimum code coverage gate** configured in `pyproject.toml`.
- If a developer introduces new code or API endpoints without writing corresponding tests, the overall statement coverage falls below 80%.
- In CI, the command `pytest --cov=app --cov-fail-under=80` returns an exit code of `1` upon coverage deficit, halting the build and blocking promotion to UAT.
- Interactive HTML coverage reports are archived on every CI run under the `code-coverage-report` artifact.

### Dynamic Route Auto-Discovery Gate
In `tests/integration/test_integration_api.py`, `test_dynamic_route_auto_discovery` dynamically inspects `app.routes` at test execution time:
- Automatically discovers all registered endpoints in the FastAPI router.
- Pings every non-parameterized GET route.
- Guarantees that any newly added endpoint does not crash with a 500 Internal Server Error, even before dedicated feature tests are written.

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

## 4. Promotion & Fast-Forward Guarantee

1. **Promote the Same Commit:** The pipeline never creates a merge commit when promoting to production. It pushes the exact, tested commit SHA (`${{ github.sha }}`) to `refs/heads/production`.
2. **Fast-Forward Only:** If `production` has diverged, the promotion step **fails loudly** and refuses to force-push.
3. **Approval Gate:** The `promote-to-production` job is bound to the `production` GitHub Environment. GitHub Actions pauses execution until an authorized reviewer approves the deployment.

---

## 5. Deployment & Rollback Operations

### Automated Rollback
If the production deployment completes but the subsequent smoke test (`scripts/smoke_test.sh`) fails:
1. The step `Auto-Rollback on Smoke Test Failure` activates automatically.
2. It fetches the previously deployed commit SHA (`steps.prev_sha.outputs.sha`).
3. It executes `scripts/rollback.sh production <previous_sha>`, which re-runs `docker-compose -f docker-compose.yml up -d --build` for the previous SHA.
4. The final `notify` step dispatches a failure alert.

### Manual Rollback (`rollback.yml`)
If a release needs to be rolled back manually:
1. Navigate to **Actions → Manual Rollback** in the GitHub repository.
2. Click **Run workflow**.
3. Select the environment (`uat` or `production`).
4. Enter the known-good commit SHA or release tag.
5. Click **Run workflow**.
