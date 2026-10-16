# Frontend Build-Time URL Injection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement build-time API URL injection into the frontend container via Docker `ARG API_URL` and `config.js` so different backend endpoints can be baked into UAT and Production builds.

**Architecture:** `Dockerfile.frontend` accepts `ARG API_URL=""` and dynamically writes `window.__APP_CONFIG__ = { API_BASE_URL: "${API_URL}" };` into `/usr/share/nginx/html/config.js`. `frontend/index.html` loads this script, falling back to relative `/api` if empty, and displays the compiled target on the UI. `docker-compose.yml` and `.github/workflows/uat-to-prod.yml` pass `API_URL` as a build argument during respective deployment stages.

**Tech Stack:** Docker, Alpine Nginx, HTML5, Vanilla JavaScript, Docker Compose, GitHub Actions.

---

### Task 1: Update Frontend Container and HTML for `config.js` Injection

**Files:**
- Modify: `Dockerfile.frontend`
- Modify: `frontend/index.html`

- [x] **Step 1: Update `Dockerfile.frontend` to accept `ARG API_URL` and generate `config.js`**

```dockerfile
FROM nginx:alpine

# Accept build argument for backend API URL
ARG API_URL=""

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy frontend source and custom reverse proxy config
COPY frontend/index.html /usr/share/nginx/html/index.html
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf

# Generate config.js at build time with the injected API_URL
RUN echo "window.__APP_CONFIG__ = { API_BASE_URL: '${API_URL}' };" > /usr/share/nginx/html/config.js

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --start-period=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

- [x] **Step 2: Update `frontend/index.html` to consume `config.js` with fallback**

Add `<script src="/config.js"></script>` and update `checkBackendHealth()`:
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
    .badge-info { background: #0369a1; color: white; margin-left: 8px; }
    .btn { background: #0284c7; color: white; border: none; padding: 10px 18px; border-radius: 6px; cursor: pointer; font-size: 15px; }
    .btn:hover { background: #0369a1; }
    pre { background: #0b0f19; padding: 16px; border-radius: 8px; overflow-x: auto; color: #a5f3fc; }
  </style>
  <!-- Load build-time injected configuration -->
  <script src="/config.js"></script>
</head>
<body>
  <div class="card">
    <h1>🚀 OrderHub Platform Dashboard</h1>
    <p>Multi-Container Deployment: <strong>Frontend (Nginx) + Backend (FastAPI)</strong></p>
    <div style="margin-bottom: 12px;">
      Status: <span id="status-badge" class="badge badge-ok">Checking...</span>
      <span id="target-badge" class="badge badge-info">Target: Detecting...</span>
    </div>
    <button class="btn" onclick="checkBackendHealth()">Ping Backend API</button>
    <h3>Backend Health Response:</h3>
    <pre id="api-output">Click the button to test API connection...</pre>
  </div>

  <script>
    function getApiBaseUrl() {
      if (window.__APP_CONFIG__ && window.__APP_CONFIG__.API_BASE_URL) {
        return window.__APP_CONFIG__.API_BASE_URL.replace(/\/$/, "");
      }
      return ""; // Default to relative URL
    }

    async function checkBackendHealth() {
      const badge = document.getElementById('status-badge');
      const targetBadge = document.getElementById('target-badge');
      const output = document.getElementById('api-output');
      const apiBase = getApiBaseUrl();

      targetBadge.innerText = apiBase ? `Compiled Target: ${apiBase}` : 'Mode: Relative Reverse-Proxy';

      const healthEndpoint = `${apiBase}/api/health`;

      try {
        const res = await fetch(healthEndpoint);
        const data = await res.json();
        badge.innerText = 'Connected: ' + data.status.toUpperCase();
        badge.style.background = '#059669';
        output.innerText = JSON.stringify(data, null, 2);
      } catch (err) {
        badge.innerText = 'Disconnected';
        badge.style.background = '#dc2626';
        output.innerText = `Error connecting to backend at ${healthEndpoint}: ${err.message}`;
      }
    }
    window.onload = checkBackendHealth;
  </script>
</body>
</html>
```

- [x] **Step 3: Commit**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add Dockerfile.frontend frontend/index.html
git commit -m "feat(docker): add ARG API_URL and config.js build-time injection to frontend"
```

---

### Task 2: Update Docker Compose for `API_URL` Build Argument

**Files:**
- Modify: `docker-compose.yml`

- [x] **Step 1: Pass `API_URL` under `frontend.build.args` in `docker-compose.yml`**

```yaml
  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
      args:
        API_URL: ${API_URL:-}
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
```

- [x] **Step 2: Commit**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add docker-compose.yml
git commit -m "feat(docker): add API_URL build arg to frontend in docker-compose.yml"
```

---

### Task 3: Update CI/CD Workflow (`uat-to-prod.yml`)

**Files:**
- Modify: `.github/workflows/uat-to-prod.yml`

- [x] **Step 1: Update `docker-build-test` to test build-time argument injection**

In `.github/workflows/uat-to-prod.yml`, update `Test Build Frontend Container` step:
```yaml
      - name: Test Build Frontend Container with Injected API_URL
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.frontend
          push: false
          build-args: |
            API_URL=https://uat-api.example.com
          tags: orderhub-frontend:test
```

- [x] **Step 2: Update `deploy.sh` to export `API_URL` during docker-compose build**

In `scripts/deploy.sh`, ensure `export API_URL="${APP_URL:-}"` is exported before building containers:
```bash
export API_URL="${APP_URL:-}"
```

- [x] **Step 3: Commit**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add .github/workflows/uat-to-prod.yml scripts/deploy.sh
git commit -m "ci(docker): pass API_URL build argument during CI build validation and deployment"
```

---

### Task 4: Documentation & Verification

**Files:**
- Modify: `docs/PIPELINE.md`

- [x] **Step 1: Document Build-Time URL Injection in `docs/PIPELINE.md`**

Add an explanation in Section 2 of `docs/PIPELINE.md` showing how developers and CI can build the frontend with specific target URLs using `--build-arg API_URL=...`.

- [x] **Step 2: Run all local tests (`python -m pytest tests/`) to ensure no regressions**

Run: `python -m pytest tests/`
Expected: All 23 tests pass.

- [ ] **Step 3: Commit and push to `uat`**

```bash
git add docs/PIPELINE.md
git commit -m "docs(docker): document build-time API_URL injection in PIPELINE.md"
git push origin uat
```

- [ ] **Step 4: Verify complete pipeline run on GitHub Actions**

Verify that `docker-build-test`, `deploy-uat`, and downstream jobs build and pass cleanly.
