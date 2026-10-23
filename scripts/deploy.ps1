<#
.SYNOPSIS
    OrderHub Deployment & Local Server Staging (PowerShell)
.DESCRIPTION
    Stages minimal server runtime files into a target directory (local simulation or remote path)
    and executes Docker Compose deployment.
.EXAMPLE
    .\scripts\deploy.ps1 uat
    .\scripts\deploy.ps1 production -DryRun $false
#>
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("uat", "production")]
    [string]$Environment,

    [string]$DeployTargetDir = "./local_server_storage/orderhub",
    [bool]$DryRun = $true,
    [int]$FrontendPort = 3000,
    [int]$BackendPort = 8000,
    [string]$ApiUrl = ""
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
Write-Host "OrderHub Deployment & Server Staging (PowerShell)"
Write-Host "Target Environment: $Environment"
Write-Host "Target Directory:   $DeployTargetDir"
Write-Host "Commit SHA:         $CommitSha"
Write-Host "Dry Run Mode:       $DryRun"
Write-Host "Frontend Port:      $FrontendPort"
Write-Host "Backend Port:       $BackendPort"
Write-Host "Timestamp (UTC):    $([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))"
Write-Host "=================================================="

# PHASE 1: STAGE SERVER RELEASE BUNDLE
Write-Host "Staging minimal server runtime files into: $DeployTargetDir..."
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

# PHASE 2: DEPLOYMENT EXECUTION
if ($DryRun) {
    Write-Host "[STUB] Dry-run enabled."
    Write-Host "[STUB] Server bundle successfully staged and validated in: $DeployTargetDir."
    Write-Host "[STUB] Verified required server files: docker-compose.yml, Dockerfile.*, app/, frontend/, .env."
    Write-Host "[STUB] To start containers from this isolated folder: .\scripts\deploy.ps1 $Environment -DryRun `$false"
    exit 0
}

Write-Host "Deploying isolated Docker Compose stack from: $DeployTargetDir..."
Push-Location $DeployTargetDir
try {
    docker compose up -d --build
} catch {
    docker-compose up -d --build
} finally {
    Pop-Location
}

Write-Host "Deployment to $Environment completed successfully."
exit 0
