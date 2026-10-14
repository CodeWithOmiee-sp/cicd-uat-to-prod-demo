# GitHub Repository & Environment Setup (`SETUP.md`)

This guide outlines the one-time configuration steps required in GitHub to enable automated UAT-to-Production pipeline promotions on `https://github.com/CodeWithOmiee-sp/cicd-uat-to-prod-demo`.

---

## Step 1: Configure GitHub Environments

1. Go to your repository on GitHub: `https://github.com/CodeWithOmiee-sp/cicd-uat-to-prod-demo/settings/environments`
2. Click **New environment** and create:
   - Environment name: `uat`
   - Environment name: `production`

### Configure Environment: `uat`
- Click `uat`.
- Environment variables: (Optional) Add `APP_URL` if you have a running preview server.

### Configure Environment: `production`
- Click `production`.
- Under **Deployment protection rules**, check **Required reviewers** ✅.
- Search for your GitHub username (`CodeWithOmiee-sp`) and select it.
- Click **Save protection rules**.

---

## Step 2: Configure Repository Secrets

Navigate to **Settings** → **Secrets and variables** → **Actions**:

1. **`PROMOTE_TOKEN`** (Required for Fast-Forward Push):
   - Generate a GitHub Personal Access Token (PAT classic) with `repo` scope at: https://github.com/settings/tokens/new
   - Add it as a repository secret named `PROMOTE_TOKEN`.
2. **`SLACK_WEBHOOK_URL`** (Optional):
   - Add incoming Slack webhook URL for notifications.
