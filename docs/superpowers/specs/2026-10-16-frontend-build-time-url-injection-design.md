# Frontend Build-Time URL Injection Design Specification

**Date:** 2026-10-16  
**Status:** Approved  
**Feature:** Build-Time API URL Injection via `ARG API_URL` and `config.js`

---

## 1. Overview & Problem Statement

Modern single-page applications and web dashboards often need their backend API endpoints defined during the container build process. When moving from UAT to Production, the frontend must point to:
- `http://uat.company.com:8000` (or `vars.APP_URL` on UAT)
- `https://company.com` (or `vars.APP_URL` on Production)

While our previous Nginx reverse-proxy setup handled relative `/api` paths cleanly, teams requiring explicit API domain binding need the URL compiled into the frontend build artifact at image creation time.

---

## 2. Architecture & Design

### Dual-Mode `config.js` Architecture

```
GitHub Actions / Docker Compose
       │
       │ (passes --build-arg API_URL="https://uat-api.example.com")
       ▼
Dockerfile.frontend (Build Time)
       │
       │ Generates /usr/share/nginx/html/config.js:
       │ window.__APP_CONFIG__ = { API_BASE_URL: "https://uat-api.example.com" };
       ▼
Browser / Client (Runtime)
       │
       ├── Reads window.__APP_CONFIG__.API_BASE_URL
       │   └── If provided: fetches "https://uat-api.example.com/api/health"
       └── If empty (e.g. local dev): falls back to relative "/api/health"
```

### Components

1. **`Dockerfile.frontend`**:
   - Adds `ARG API_URL=""`.
   - Runs a build step that writes:
     ```javascript
     window.__APP_CONFIG__ = { API_BASE_URL: "${API_URL}" };
     ```
     into `/usr/share/nginx/html/config.js`.

2. **`frontend/index.html`**:
   - Imports `<script src="/config.js"></script>`.
   - Fallback logic:
     ```javascript
     const apiBase = (window.__APP_CONFIG__ && window.__APP_CONFIG__.API_BASE_URL) || '';
     const res = await fetch(`${apiBase}/api/health`);
     ```
   - Renders the active `API_BASE_URL` on the dashboard badge for immediate visual verification.

3. **`docker-compose.yml`**:
   - Adds build args to frontend service:
     ```yaml
     frontend:
       build:
         context: .
         dockerfile: Dockerfile.frontend
         args:
           API_URL: ${API_URL:-}
     ```

4. **CI/CD Workflow (`uat-to-prod.yml`)**:
   - In `docker-build-test`, tests building with `--build-arg API_URL=https://api.test.example.com`.
   - In `deploy-uat` and `promote-to-production`, sets `API_URL: ${{ vars.APP_URL }}`.

---

## 3. Verification Strategy

1. Verify `Dockerfile.frontend` builds with default empty `API_URL` (relative path mode).
2. Verify `Dockerfile.frontend` builds with `--build-arg API_URL=http://uat.example.com:8000` and `config.js` contains the injected URL.
3. Run all 23 local tests (`python -m pytest tests/`) to ensure no regressions.
4. Push to `uat` branch and verify the GitHub Actions pipeline builds both containers and passes all test/deploy gates.
