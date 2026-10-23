# Graceful Docker Stop, Replace & Auto-Run Lifecycle Design Specification

**Date:** 2026-10-23  
**Status:** Approved  
**Feature:** Graceful Docker Stop, Artifact Replacement, and Automated Health Check Lifecycle  

---

## 1. Overview & Problem Statement

When deploying code updates to a target directory (such as a local test folder or a server path), existing Docker containers may already be running and bound to the host ports (`8000` for backend, `3000` for frontend).

Overwriting files while containers are actively running can cause:
1. File lock collisions on active container volume mounts.
2. Port binding conflicts (`bind: address already in use`).
3. Outdated in-memory code remaining active despite filesystem updates.

This design introduces an automated **Stop → Replace → Build & Run → Health Check** deployment lifecycle to ensure reliable zero-conflict deployments.

---

## 2. Five-Phase Deployment Lifecycle

```
[Start Deploy]
      │
      ▼ Phase 1: Pre-Deployment Stop Guard
Does $DeployTargetDir contain an active docker compose stack?
      ├── YES ──► docker compose down (stops containers, frees ports 3000 & 8000)
      └── NO  ──► Proceed
      │
      ▼ Phase 2: Clean & Stage Release Artifacts
Stage minimal runtime files into $DeployTargetDir:
      - app/, frontend/, requirements.txt
      - docker-compose.yml, Dockerfile.backend, Dockerfile.frontend
      - generated .env
      - release_manifest.txt
      │
      ▼ Phase 3: Automated Docker Build & Start
In $DeployTargetDir:
      docker compose up -d --build (builds fresh images and starts containers)
      │
      ▼ Phase 4: Automated Smoke Health Check
Loop with retry (5 attempts, 3s delay):
      - Backend:  curl http://localhost:8000/api/health -> 200 OK
      - Frontend: curl http://localhost:3000 -> 200 OK
      │
      ▼ Phase 5: Result Reporting
      ├── All 200 OK ──► ✅ SUCCESS: Service healthy and running
      └── Failed     ──► ❌ ERROR: Dumps docker compose logs for debugging
```

---

## 3. Configuration Parameters

The deployment scripts (`deploy.ps1` and `deploy.sh`) support:

- `Environment`: `uat` or `production` (mandatory).
- `DeployTargetDir`: Target folder path (default: `./local_server_storage/orderhub`).
- `AutoRun`: Boolean flag (default `$true` for automatic execution, or pass `-DryRun` for simulation).
- `BackendPort`: Target port for backend (default `8000`).
- `FrontendPort`: Target port for frontend (default `3000`).
- `ApiUrl`: Optional custom backend URL to inject into frontend.

---

## 4. Error Handling & Safety

1. **Docker Daemon Availability**: If Docker Desktop / Docker Engine is not running or unavailable, the script fails gracefully with an actionable error message (`Docker daemon is not reachable. Please start Docker.`).
2. **Health Check Failure**: If the containers start but fail health checks within 15 seconds, the script automatically executes `docker compose logs --tail=50` to output the exact container error before exiting with code 1.
3. **Safe Cleanup**: If `docker compose down` fails (e.g. no containers exist), the error is caught and ignored so deployment proceeds normally.
