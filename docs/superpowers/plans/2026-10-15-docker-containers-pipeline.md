# Multi-Container Docker Pipeline Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate a multi-container Docker architecture (Frontend in Nginx container + Backend in FastAPI container orchestrated with Docker Compose) into the automated UAT-to-Production CI/CD pipeline.

**Architecture:** A multi-container stack orchestrated via `docker-compose.yml` where a frontend Nginx container serves UI and proxies `/api` calls to an isolated backend FastAPI container. The CI/CD pipeline validates container builds in CI, deploys both containers via Docker Compose on UAT with dual-endpoint smoke tests, validates with E2E feature journeys, and promotes to Production upon manual approval with container auto-rollback.

**Tech Stack:** Docker, Docker Compose, Nginx (Alpine), FastAPI/Python 3.11, Pytest, GitHub Actions, Bash (`set -euo pipefail`).

---

### Task 1: Backend Dockerfile (`Dockerfile.backend`)

**Files:**
- Create: `Dockerfile.backend`
- Create: `.dockerignore`

- [ ] **Step 1: Create `.dockerignore` to exclude local caches and git metadata from container builds**

```dockerignore
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
test-reports/
.git/
.venv/
venv/
.env*
!config/.env.example
```

- [ ] **Step 2: Create `Dockerfile.backend` for the FastAPI service**

```dockerfile
# Multi-stage lightweight Python runtime
FROM python:3.11-slim

WORKDIR /app

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    PORT=8000

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/ app/
COPY config/ config/

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 3: Commit**

```bash
git add .dockerignore Dockerfile.backend
git commit -m "feat(docker): add backend Dockerfile and dockerignore"
```

---

### Task 2: Frontend Container (`frontend/` and `Dockerfile.frontend`)

**Files:**
- Create: `frontend/index.html`
- Create: `frontend/nginx.conf`
- Create: `Dockerfile.frontend`

- [ ] **Step 1: Create `frontend/index.html` with real-time API health dashboard**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OrderHub Platform Dashboard</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; background: #0f172a; color: #f8fafc; }
    .card { background: #1e293b; border-radius: 12px; padding: 24px; max-width: 650px; margin: 0 auto; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
    h1 { margin-top: 0; color: #38bdf8; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 9999px; font-size: 14px; font-weight: 600; }
    .badge-ok { background: #059669; color: white; }
    .btn { background: #0284c7; color: white; border: none; padding: 10px 18px; border-radius: 6px; cursor: pointer; font-size: 15px; }
    .btn:hover { background: #0369a1; }
    pre { background: #0b0f19; padding: 16px; border-radius: 8px; overflow-x: auto; color: #a5f3fc; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 OrderHub Platform Dashboard</h1>
    <p>Multi-Container Deployment: <strong>Frontend (Nginx) + Backend (FastAPI)</strong></p>
    <div>
      Status: <span id="status-badge" class="badge badge-ok">Checking...</span>
    </div>
    <br>
    <button class="btn" onclick="checkBackendHealth()">Ping Backend API</button>
    <h3>Backend Health Response:</h3>
    <pre id="api-output">Click the button to test API connection...</pre>
  </div>

  <script>
    async function checkBackendHealth() {
      const badge = document.getElementById('status-badge');
      const output = document.getElementById('api-output');
      try {
        const res = await fetch('/api/health');
        const data = await res.json();
        badge.innerText = 'Connected: ' + data.status.toUpperCase();
        output.innerText = JSON.stringify(data, null, 2);
      } catch (err) {
        badge.innerText = 'Disconnected';
        badge.style.background = '#dc2626';
        output.innerText = 'Error connecting to backend: ' + err.message;
      }
    }
    // Auto-check on load
    window.onload = checkBackendHealth;
  </script>
</body>
</html>
```

- [ ] **Step 2: Create `frontend/nginx.conf` reverse proxying `/api/` to backend container**

```nginx
server {
    listen 80;
    server_name localhost;

    # Serve static frontend web application
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    # Reverse proxy API requests to backend container
    location /api/ {
        proxy_pass http://backend:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Health check for Nginx container itself
    location /healthz {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
```

- [ ] **Step 3: Create `Dockerfile.frontend`**

```dockerfile
FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy frontend source and custom reverse proxy config
COPY frontend/index.html /usr/share/nginx/html/index.html
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --start-period=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 4: Commit**

```bash
git add frontend/ Dockerfile.frontend
git commit -m "feat(docker): add frontend Nginx configuration and Dockerfile"
```

---

### Task 3: Multi-Container Orchestration (`docker-compose.yml`)

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create `docker-compose.yml` linking Frontend and Backend**

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    image: orderhub-backend:latest
    container_name: orderhub-backend
    restart: unless-stopped
    ports:
      - "${BACKEND_PORT:-8000}:8000"
    environment:
      - APP_ENV=${APP_ENV:-uat}
      - PORT=8000
    networks:
      - orderhub-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    image: orderhub-frontend:latest
    container_name: orderhub-frontend
    restart: unless-stopped
    ports:
      - "${FRONTEND_PORT:-3000}:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - orderhub-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/healthz"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 3s

networks:
  orderhub-network:
    driver: bridge
```

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(docker): add multi-container docker-compose orchestration"
```

---

### Task 4: Upgrade Deployment, Smoke Test, and Rollback Scripts

**Files:**
- Modify: `scripts/deploy.sh`
- Modify: `scripts/smoke_test.sh`
- Modify: `scripts/rollback.sh`

- [ ] **Step 1: Update `scripts/deploy.sh` with Docker Compose deployment commands**

Add Docker Compose orchestration commands under the real deployment section:
```bash
# In scripts/deploy.sh:
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Dry-run enabled. Simulated Docker Compose deployment of frontend & backend to $ENVIRONMENT succeeded."
  exit 0
fi

echo "Deploying Docker Compose stack to $ENVIRONMENT..."
export APP_ENV="$ENVIRONMENT"
export FRONTEND_PORT="${FRONTEND_PORT:-3000}"
export BACKEND_PORT="${BACKEND_PORT:-8000}"

docker-compose -f docker-compose.yml down || true
docker-compose -f docker-compose.yml up -d --build
```

- [ ] **Step 2: Update `scripts/smoke_test.sh` to check BOTH Frontend and Backend containers**

Check both port 8000 (`/api/health`) and port 3000 (`/healthz` or `/`):
```bash
# In scripts/smoke_test.sh:
# Validates both Backend container health and Frontend container health
```

- [ ] **Step 3: Update `scripts/rollback.sh` with Docker rollback logic**

```bash
# In scripts/rollback.sh:
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[STUB] Simulated Docker Compose rollback of $ENVIRONMENT to $TARGET_SHA succeeded."
  exit 0
fi

git checkout "$TARGET_SHA"
docker-compose -f docker-compose.yml up -d --build
```

- [ ] **Step 4: Commit**

```bash
git add scripts/
git commit -m "feat(scripts): update deploy, smoke_test, and rollback for Docker Compose"
```

---

### Task 5: CI/CD Workflow Update (`uat-to-prod.yml`)

**Files:**
- Modify: `.github/workflows/uat-to-prod.yml`

- [ ] **Step 1: Add Docker Build Validation Job in CI**

Before deploying to UAT, GitHub Actions verifies that both `Dockerfile.backend` and `Dockerfile.frontend` build cleanly without errors:
```yaml
  docker-build-test:
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
          tags: orderhub-backend:test

      - name: Test Build Frontend Container
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.frontend
          push: false
          tags: orderhub-frontend:test
```

- [ ] **Step 2: Update `deploy-uat` dependencies**

Update `deploy-uat` needs to require `[unit-tests, edge-case-tests, integration-tests, docker-build-test]`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/uat-to-prod.yml
git commit -m "ci(docker): add docker build validation job to CI pipeline"
```

---

### Task 6: Documentation & Verification

**Files:**
- Modify: `docs/PIPELINE.md`
- Modify: `config/.env.example`

- [ ] **Step 1: Document Docker multi-container run commands in `docs/PIPELINE.md`**
- [ ] **Step 2: Run all local tests (`python -m pytest tests/`) and verify 23/23 pass**
- [ ] **Step 3: Push to `uat` and verify complete pipeline execution on GitHub Actions**
