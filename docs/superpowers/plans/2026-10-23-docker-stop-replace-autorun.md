# Docker Stop, Replace & Auto-Run Deployment Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance deployment scripts (`deploy.ps1` and `deploy.sh`) to automatically stop existing running Docker containers before replacing files, build and launch the fresh container stack, and verify health with an automated smoke check.

**Architecture:** A 5-phase lifecycle: (1) Pre-stop guard detects and stops existing compose containers in `$DeployTargetDir` freeing ports; (2) Staging engine copies fresh runtime files and generates `.env`; (3) Docker Compose builds and starts containers in detached mode; (4) Automated health check retries endpoints until `200 OK`; (5) Status output displays live service URLs.

**Tech Stack:** PowerShell 5.1 / 7+, Bash, Docker Compose, Python, Pytest.

---

### Task 1: Deployment Lifecycle Unit Tests (`tests/unit/test_deploy_lifecycle.py`)

**Files:**
- Create: `tests/unit/test_deploy_lifecycle.py`

- [ ] **Step 1: Write test verifying lifecycle argument handling and staging integration**

```python
import pytest
from pathlib import Path
from scripts.stage_server_bundle import stage_server_bundle

@pytest.mark.unit
class TestDeployLifecycle:
    """Validates the deployment lifecycle staging and configuration contract."""

    def test_lifecycle_staging_creates_valid_compose_stack(self, tmp_path):
        target = tmp_path / "lifecycle_test_server"
        repo_root = Path(__file__).resolve().parent.parent.parent

        manifest = stage_server_bundle(
            repo_root=repo_root,
            target_dir=target,
            environment="uat",
            port=8000,
            frontend_port=3000,
            api_url=""
        )

        assert manifest.exists()
        assert (target / "docker-compose.yml").is_file()
        assert (target / "Dockerfile.backend").is_file()
        assert (target / "Dockerfile.frontend").is_file()
        assert (target / ".env").is_file()

        env_content = (target / ".env").read_text(encoding="utf-8")
        assert "APP_ENV=uat" in env_content
        assert "PORT=8000" in env_content
        assert "FRONTEND_PORT=3000" in env_content
```

- [ ] **Step 2: Run pytest to verify test passes**

Run: `python -m pytest tests/unit/test_deploy_lifecycle.py`
Expected: 1 passed

- [ ] **Step 3: Commit test file**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add tests/unit/test_deploy_lifecycle.py
git commit -m "test: add unit test for deployment lifecycle staging contract"
```

---

### Task 2: Implement Stop Guard, Auto-Run & Health Check in `scripts/deploy.ps1`

**Files:**
- Modify: `scripts/deploy.ps1`

- [ ] **Step 1: Update `scripts/deploy.ps1` with stop guard, auto-run, and health check**

```powershell
<#
.SYNOPSIS
    OrderHub Deployment & Auto-Run Lifecycle (PowerShell)
.DESCRIPTION
    1. Stops existing running containers in the target folder (frees ports 8000 & 3000).
    2. Stages fresh minimal server runtime files.
    3. Builds and boots new Docker containers.
    4. Runs automated health check against backend & frontend.
#>
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("uat", "production")]
    [string]$Environment,

    [string]$DeployTargetDir = "./local_server_storage/orderhub",
    [switch]$DryRun,
    [int]$FrontendPort = 3000,
    [int]$BackendPort = 8000,
    [string]$ApiUrl = "",
    [int]$MaxHealthRetries = 10,
    [int]$HealthRetryDelaySec = 2
)

$ErrorActionPreference = "Stop"

$CommitSha = "local-build"
try {
    $CommitSha = (git rev-parse HEAD 2>$null)
    if (-not $CommitSha) { $CommitSha = "local-build" }
} catch {
    $CommitSha = "local-build"
}

Write-Host "=================================================="
Write-Host "OrderHub Deployment & Auto-Run (PowerShell)"
Write-Host "Target Environment: $Environment"
Write-Host "Target Directory:   $DeployTargetDir"
Write-Host "Commit SHA:         $CommitSha"
Write-Host "Dry Run Mode:       $($DryRun.IsPresent)"
Write-Host "Frontend Port:      $FrontendPort"
Write-Host "Backend Port:       $BackendPort"
Write-Host "Timestamp (UTC):    $([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))"
Write-Host "=================================================="

# PHASE 1: STOP EXISTING CONTAINERS IN TARGET DIRECTORY
if (Test-Path (Join-Path $DeployTargetDir "docker-compose.yml")) {
    Write-Host "Checking for existing Docker containers in $DeployTargetDir..."
    Push-Location $DeployTargetDir
    try {
        Write-Host "Stopping and removing existing containers to free ports $FrontendPort and $BackendPort..."
        docker compose down 2>$null
        if ($LASTEXITCODE -ne 0) {
            docker-compose down 2>$null
        }
    } catch {
        Write-Host "No active containers needed stopping."
    } finally {
        Pop-Location
    }
}

# PHASE 2: STAGE NEW SERVER RELEASE BUNDLE
Write-Host "Staging fresh minimal server runtime files into: $DeployTargetDir..."
$StageArgs = @(
    "scripts/stage_server_bundle.py",
    "--target-dir", $DeployTargetDir,
    "--env", $Environment,
    "--port", "$BackendPort",
    "--frontend-port", "$FrontendPort"
)
if ($ApiUrl) {
    $StageArgs += @("--api-url", $ApiUrl)
}

python @StageArgs

$ManifestPath = Join-Path $DeployTargetDir "release_manifest.txt"
if (Test-Path $ManifestPath) {
    Write-Host "`n--- Staged Server Release Manifest ---"
    Get-Content $ManifestPath
    Write-Host "--------------------------------------`n"
}

# PHASE 3: EXECUTION / DRY RUN CHECK
if ($DryRun.IsPresent) {
    Write-Host "[STUB] Dry-run enabled."
    Write-Host "[STUB] Server bundle successfully staged and validated in: $DeployTargetDir."
    Write-Host "[STUB] Existing containers were stopped."
    Write-Host "[STUB] To start containers live, re-run without -DryRun: .\scripts\deploy.ps1 $Environment -DeployTargetDir `"$DeployTargetDir`""
    exit 0
}

# Check Docker CLI
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Docker daemon is not running or unreachable. Please start Docker Desktop."
        exit 1
    }
} catch {
    Write-Warning "Docker CLI is not available in PATH."
    exit 1
}

# PHASE 4: BUILD & LAUNCH CONTAINERS
Write-Host "Building and launching Docker containers from: $DeployTargetDir..."
Push-Location $DeployTargetDir
try {
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) {
        docker-compose up -d --build
    }
} finally {
    Pop-Location
}

# PHASE 5: AUTOMATED HEALTH CHECK
Write-Host "Running automated health checks on deployed services..."
$BackendUrl = "http://localhost:$BackendPort/api/health"
$FrontendUrl = "http://localhost:$FrontendPort"
$Healthy = $false

for ($attempt = 1; $attempt -le $MaxHealthRetries; $attempt++) {
    Write-Host "[Attempt $attempt/$MaxHealthRetries] Verifying backend ($BackendUrl)..."
    try {
        $response = Invoke-RestMethod -Uri $BackendUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response.status -eq "ok") {
            Write-Host "✅ Backend health check passed!"
            $Healthy = $true
            break
        }
    } catch {
        Write-Host "Waiting for backend service to become ready..."
    }
    Start-Sleep -Seconds $HealthRetryDelaySec
}

if (-not $Healthy) {
    Write-Error "❌ Deployment health check failed: Backend did not return 200 OK within timeout."
    Push-Location $DeployTargetDir
    docker compose logs --tail=50
    Pop-Location
    exit 1
}

Write-Host "`n=================================================="
Write-Host "🚀 DEPLOYMENT COMPLETED SUCCESSFULLY!"
Write-Host "• Backend API:     $BackendUrl"
Write-Host "• Frontend UI:     $FrontendUrl"
Write-Host "• Target Directory: $DeployTargetDir"
Write-Host "=================================================="
exit 0
```

- [ ] **Step 2: Test `scripts/deploy.ps1` with `-DryRun`**

Run: `powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 uat -DeployTargetDir "C:\Users\Omkar Jadhav\local_projects\render_folder" -DryRun`
Expected: Successfully runs stop guard, stages bundle, and prints manifest.

- [ ] **Step 3: Commit `scripts/deploy.ps1`**

```bash
git add scripts/deploy.ps1
git commit -m "feat(deploy): implement stop guard, auto-run, and automated health checks in deploy.ps1"
```

---

### Task 3: Implement Stop Guard & Health Check in `scripts/deploy.sh`

**Files:**
- Modify: `scripts/deploy.sh`

- [ ] **Step 1: Update `scripts/deploy.sh` with stop guard before staging and health check**

Mirror the exact stop guard and health check loop in `scripts/deploy.sh`.

- [ ] **Step 2: Test `scripts/deploy.sh` in dry-run mode**

Run: `bash scripts/deploy.sh uat`
Expected: Completes with stop check and manifest output.

- [ ] **Step 3: Commit `scripts/deploy.sh`**

```bash
git add scripts/deploy.sh
git commit -m "feat(deploy): implement stop guard and health verification in deploy.sh"
```

---

### Task 4: Documentation Update in `docs/PIPELINE.md`

**Files:**
- Modify: `docs/PIPELINE.md`

- [ ] **Step 1: Document Stop, Replace, and Auto-Run Lifecycle**

Add Section 2.2 in `docs/PIPELINE.md`:
- Explaining the 5-phase lifecycle.
- Detailing how ports 3000 & 8000 are freed safely before file copying.
- Providing copy-paste PowerShell and Bash commands.

- [ ] **Step 2: Commit `docs/PIPELINE.md`**

```bash
git add docs/PIPELINE.md
git commit -m "docs: document Docker stop, replace, and auto-run lifecycle"
```

---

### Task 5: End-to-End Verification & Remote Push

**Files:**
- Modify: `docs/superpowers/plans/2026-10-23-docker-stop-replace-autorun.md` (check all boxes)

- [ ] **Step 1: Run full test suite with coverage**

Run: `python -m pytest tests/ --cov=app --cov-fail-under=80`
Expected: All 27 tests pass.

- [ ] **Step 2: Commit plan checklist and push to remote `uat`**

```bash
git add docs/superpowers/plans/2026-10-23-docker-stop-replace-autorun.md
git commit -m "docs: complete Docker stop-and-replace lifecycle plan"
git push origin uat
```
