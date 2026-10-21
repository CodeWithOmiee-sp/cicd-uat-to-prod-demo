# Local Server Staging & Deployment Simulation Design Specification

**Date:** 2026-10-21  
**Status:** Approved  
**Feature:** Local Server Staging & Deployment Pre-Flight Simulation  

---

## 1. Overview & Problem Statement

Before deploying an application stack to a remote production/staging server (via SSH, rsync, or on-prem VM runner), operations teams and developers need answers to two critical questions:
1. **What exact files are required to run on the server?** (Excluding test caches, git logs, dev virtualenvs, and CI scripts).
2. **Will the packaged build start and pass health checks in complete isolation?**

Currently, `scripts/deploy.sh` operates as a stub/placeholder or assumes files are already present on the target server. 

This design establishes a **Local Server Staging & Pre-Flight Verification** mechanism:
- Stages the minimal runtime bundle into a local directory (`$DEPLOY_TARGET_DIR`, default `./local_server_storage/orderhub`) simulating the remote server's filesystem.
- Generates a cryptographically trackable `release_manifest.txt` detailing every staged artifact, size, and timestamp.
- Verifies that Docker Compose starts cleanly and passes health smoke checks *directly from within the isolated staged path*.
- When validated locally, switching to the real server is simply a matter of changing `DEPLOY_TARGET_DIR` (e.g., `/opt/orderhub` or remote SSH host).

---

## 2. Architecture & Directory Flow

```
Development Repo (c:\Users\...\cicd-uat-to-prod-demo)
  ├── app/                  (Backend API)
  ├── frontend/             (Nginx Web UI)
  ├── docker-compose.yml    (Orchestration)
  ├── Dockerfile.backend    (FastAPI Image)
  ├── Dockerfile.frontend   (Nginx UI Image)
  ├── requirements.txt      (Python packages)
  └── scripts/smoke_test.sh (Health test)
          │
          ▼ [Staging & Manifest Step]
  Copies minimal runtime files & generates .env
          │
          ▼
Target Destination: $DEPLOY_TARGET_DIR
(Local Simulation: ./local_server_storage/orderhub)
(Future Production: /opt/orderhub or remote VM via SSH/SCP)
  ├── app/
  ├── frontend/
  ├── docker-compose.yml
  ├── Dockerfile.backend
  ├── Dockerfile.frontend
  ├── requirements.txt
  ├── scripts/smoke_test.sh
  ├── .env
  └── release_manifest.txt  <-- Complete audit trail of files on server
          │
          ▼ [Isolated Execution & Verification]
  cd "$DEPLOY_TARGET_DIR"
  docker compose -f docker-compose.yml up -d --build
  ./scripts/smoke_test.sh http://localhost:8000 http://localhost:8080
```

---

## 3. Server Runtime Artifact Manifest

The server destination will receive **only** the necessary files to run the production stack:

| File / Folder | Purpose on Server | Included in Staging? |
|---|---|:---:|
| `docker-compose.yml` | Multi-container Docker orchestration | ✅ Yes |
| `Dockerfile.backend` | Backend FastAPI container definition | ✅ Yes |
| `Dockerfile.frontend` | Frontend Nginx container definition | ✅ Yes |
| `app/` | Backend application code & endpoints | ✅ Yes |
| `frontend/` | UI dashboard HTML, CSS, JS | ✅ Yes |
| `requirements.txt` | Python runtime dependencies | ✅ Yes |
| `.env` (Generated) | Environment configs (`PORT`, `API_URL`, `APP_ENV`) | ✅ Yes |
| `scripts/smoke_test.sh` | Post-deployment automated health check | ✅ Yes |
| `release_manifest.txt` | Generated file index with timestamps & sizes | ✅ Yes |
| `tests/` | Unit, edge, integration test files | ❌ Excluded |
| `.git/` | Git internal object database | ❌ Excluded |
| `.pytest_cache/`, `.ruff_cache/` | Linter and test caches | ❌ Excluded |
| `.github/` | CI/CD workflow YAMLs | ❌ Excluded |

---

## 4. Key Configuration Parameters

Environment variables govern the staging and destination paths:

- `DEPLOY_TARGET_DIR`: Target directory path.
  - Default: `./local_server_storage/orderhub` (local test directory)
  - Remote override: `/opt/orderhub` or remote mount path.
- `ENVIRONMENT`: Target environment name (`uat` or `production`).
- `PORT`: Backend port (default `8000`).
- `FRONTEND_PORT`: Frontend port (default `8080`).
- `API_URL`: Backend URL baked into frontend (e.g. `http://localhost:8000` or production domain).
- `DRY_RUN`: If `true`, simulates file staging and outputs the planned manifest without launching containers. If `false`, copies files and boots the stack from the staging directory.

---

## 5. Verification Strategy

1. **Automated Unit/Integration Test (`tests/unit/test_deploy_staging.py`)**:
   - Tests that invoking the staging function creates the target directory.
   - Asserts that all required runtime files (`app/`, `frontend/`, `docker-compose.yml`, `Dockerfile.*`, `.env`, `release_manifest.txt`) are present.
   - Asserts that dev/test files (`tests/`, `.git`, `.pytest_cache`) are strictly excluded.
2. **Local Simulation Run**:
   - Execute `./scripts/deploy.sh uat` in local staging mode.
   - Inspect the generated `./local_server_storage/orderhub/release_manifest.txt`.
   - Verify health check response.
