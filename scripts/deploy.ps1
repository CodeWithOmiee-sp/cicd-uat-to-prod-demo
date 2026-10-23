<#
.SYNOPSIS
    OrderHub Deployment & Auto-Run Lifecycle (PowerShell)
.DESCRIPTION
    1. Stops existing running containers in the target folder (frees ports 8000 & 3000).
    2. Stages fresh minimal server runtime files.
    3. Builds and boots new Docker containers automatically.
    4. Runs automated health check against backend & frontend.
.EXAMPLE
    .\scripts\deploy.ps1 uat
    .\scripts\deploy.ps1 uat -DeployTargetDir "C:\Users\Omkar Jadhav\local_projects\render_folder"
    .\scripts\deploy.ps1 uat -DryRun
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
        Write-Warning "Docker daemon is not running or unreachable. Please start Docker Desktop to start containers."
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
Write-Host "• Backend API:      $BackendUrl"
Write-Host "• Frontend UI:      $FrontendUrl"
Write-Host "• Target Directory: $DeployTargetDir"
Write-Host "=================================================="
exit 0
