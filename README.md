# UAT to Production Git Automation Pipeline (OrderHub Demo)

Automated GitHub Actions CI/CD pipeline demonstrating:
- Developer pushes to `uat`.
- Automated parallel quality gates (`unit-tests`, `edge-case-tests`, `integration-tests`).
- Automated deployment to UAT environment with HTTP smoke tests.
- Manual approval gate with Required Reviewers on the `production` environment.
- Fast-forward promotion to `production` branch.
- Automated rollback on failed smoke test.
- Manual rollback via GitHub Actions `workflow_dispatch`.

## Local Testing
```bash
python -m pytest tests/
```
