# Pull Request (PR) Validation Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an automated Pull Request (PR) validation workflow (`pr-validation.yml`) that validates feature branches before merging into `uat` with Lint, Unit/Edge tests, 80% Code Coverage gate, and Docker build tests.

**Architecture:** A GitHub Actions workflow triggering on `pull_request` events to `uat`. Parallel jobs run syntax linting, unit calculations, edge-case tests, code coverage enforcement (fail-under 80%), and Docker container builds. An aggregation job (`pr-gate-complete`) writes a GitHub Step Summary and serves as the single required status check for branch protection.

**Tech Stack:** GitHub Actions, Python 3.11, Ruff, Pytest, Pytest-cov, Docker Buildx.

---

### Task 1: Create PR Validation Workflow (`.github/workflows/pr-validation.yml`)

**Files:**
- Create: `.github/workflows/pr-validation.yml`

- [x] **Step 1: Write `.github/workflows/pr-validation.yml`**

```yaml
name: Pull Request Validation Gate

on:
  pull_request:
    branches:
      - uat
    types: [opened, synchronize, reopened]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write

jobs:
  pr-lint-and-unit-tests:
    name: Lint & Unit/Edge Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest pytest-cov ruff httpx
          pip install -r requirements.txt

      - name: Run linter
        run: |
          ruff check tests/ app/

      - name: Run unit and edge tests
        run: |
          pytest tests/unit tests/edge -m "unit or edge" --junitxml=test-reports/unit-edge.xml

      - name: Upload unit and edge test report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pr-unit-edge-results
          path: test-reports/unit-edge.xml

  pr-coverage-gate:
    name: Integration Tests & 80% Coverage Gate
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest pytest-cov httpx
          pip install -r requirements.txt

      - name: Run integration tests with 80% coverage gate
        run: |
          pytest tests/integration tests/unit -m "integration or unit" \
            --cov=app \
            --cov-report=term-missing \
            --cov-report=xml:test-reports/coverage.xml \
            --cov-report=html:test-reports/coverage_html \
            --cov-fail-under=80 \
            --junitxml=test-reports/integration.xml

      - name: Upload PR code coverage report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pr-code-coverage-report
          path: test-reports/coverage_html/

  pr-docker-build-test:
    name: Docker Container Build Test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Test Build Backend Container
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.backend
          push: false
          tags: orderhub-backend:pr-test

      - name: Test Build Frontend Container with Injected API_URL
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.frontend
          push: false
          build-args: |
            API_URL=https://uat-api.example.com
          tags: orderhub-frontend:pr-test

  pr-gate-complete:
    name: PR Gate Status
    needs: [pr-lint-and-unit-tests, pr-coverage-gate, pr-docker-build-test]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Evaluate PR Validation Status
        run: |
          if [[ "${{ needs.pr-lint-and-unit-tests.result }}" != "success" || \
                "${{ needs.pr-coverage-gate.result }}" != "success" || \
                "${{ needs.pr-docker-build-test.result }}" != "success" ]]; then
            echo "❌ One or more PR validation checks failed."
            echo "Lint & Unit: ${{ needs.pr-lint-and-unit-tests.result }}"
            echo "Coverage:    ${{ needs.pr-coverage-gate.result }}"
            echo "Docker:      ${{ needs.pr-docker-build-test.result }}"
            exit 1
          fi
          echo "✅ All PR validation checks passed successfully. Ready for merge into UAT!"
```

- [x] **Step 2: Commit**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add .github/workflows/pr-validation.yml
git commit -m "ci: add pull request validation gate workflow for uat branch"
```

---

### Task 2: Documentation Update in `docs/PIPELINE.md`

**Files:**
- Modify: `docs/PIPELINE.md`

- [x] **Step 1: Document PR workflow in `docs/PIPELINE.md`**

Add Section 1.1 in `docs/PIPELINE.md` documenting:
- The developer workflow from feature branch to Pull Request.
- The automated PR validation checks.
- How to configure `PR Gate Status` as a required status check in GitHub branch protection rules.

- [x] **Step 2: Commit**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add docs/PIPELINE.md
git commit -m "docs: document PR validation gate workflow and branch protection in PIPELINE.md"
```

---

### Task 3: Verification & Push to `uat`

**Files:**
- Modify: `docs/superpowers/plans/2026-10-16-pr-validation-workflow.md`

- [x] **Step 1: Run all local tests (`python -m pytest tests/`) to ensure clean state**

Run: `python -m pytest tests/`
Expected: All 23 tests pass.

- [x] **Step 2: Commit plan checklist and push to `origin/uat`**

```bash
git add docs/superpowers/plans/2026-10-16-pr-validation-workflow.md
git commit -m "docs: complete PR validation workflow plan"
git push origin uat
```

- [x] **Step 3: Verify GitHub Actions status on `uat`**

Verify that `uat-to-prod.yml` runs smoothly and `.github/workflows/pr-validation.yml` is active on GitHub.
