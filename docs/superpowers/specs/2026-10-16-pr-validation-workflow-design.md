# Pull Request (PR) Validation Workflow Design Specification

**Date:** 2026-10-16  
**Status:** Approved  
**Feature:** Automated Pre-Merge PR Validation Gate (`feat/*` → `uat`)

---

## 1. Overview & Problem Statement

In a multi-developer Git workflow, changes should not be pushed directly to the integration/testing branch (`uat`). Instead, developers work on feature branches (`feat/XYZ`) and open a Pull Request into `uat`.

Currently, testing occurs post-merge when commits hit `uat`. If a developer introduces broken code, failing tests, or drops test coverage, the `uat` branch becomes temporarily unstable.

The **Pull Request Validation Workflow** provides an automated pre-merge safety gate that runs immediately when a PR is opened or updated, blocking merge if any check fails.

---

## 2. Architecture & Pipeline Structure

```
Developer opens or pushes to PR (feat/* → uat)
            │
            ▼
GitHub Actions (.github/workflows/pr-validation.yml)
            │
  ┌─────────┴───────────────────────────────────────────────┐
  │ 1. Lint & Unit/Edge Tests (ruff + pytest unit/edge)     │
  │ 2. Code Coverage Gate (pytest-cov --cov-fail-under=80)  │ (Parallel CI Jobs)
  │ 3. Docker Build Test (Dockerfile.backend & frontend)    │
  └─────────┬───────────────────────────────────────────────┘
            │
            ▼
  [pr-gate-complete] (Final Required Status Check)
    - Consolidates status of all 3 jobs
    - Posts a Step Summary on the PR
    - Prevents PR merge if any job fails
```

---

## 3. Key Design Decisions

1. **Trigger Configuration:**
   - Triggers strictly on `pull_request` targeting the `uat` branch:
     ```yaml
     on:
       pull_request:
         branches: [uat]
         types: [opened, synchronize, reopened]
     ```

2. **Resource Efficiency (Automatic Run Cancellation):**
   - If a developer pushes multiple commits in rapid succession, previous outdated runs are cancelled automatically:
     ```yaml
     concurrency:
       group: pr-${{ github.event.pull_request.number }}
       cancel-in-progress: true
     ```

3. **No Deployment Actions in PRs:**
   - Unlike `uat-to-prod.yml`, the PR validation workflow **does not deploy** to UAT or Production. It only tests, lints, checks coverage, and verifies container builds.

4. **Required Status Check (`pr-gate-complete`):**
   - An aggregation job that depends on `[pr-lint-and-unit-tests, pr-coverage-gate, pr-docker-build-test]`. This single check can be set as a "Required status check" in repository settings so GitHub locks the "Merge pull request" button until all tests pass.

---

## 4. Verification Strategy

1. Verify `.github/workflows/pr-validation.yml` has valid GitHub Actions YAML syntax.
2. Verify all local test and lint commands (`ruff check .`, `pytest tests/`, `pytest --cov=app --cov-fail-under=80`) pass.
3. Commit and push the workflow to `origin/uat`.
4. Create a test feature branch (e.g. `feat/pr-validation-demo`), push to GitHub, and verify that opening a PR against `uat` automatically triggers all validation checks.
