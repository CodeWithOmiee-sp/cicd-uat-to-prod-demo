# Local Server Staging & Deployment Pre-Flight Simulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an automated pre-flight staging mechanism that packages minimal server runtime artifacts into a configurable local server folder (`./local_server_storage/orderhub`), validates manifest integrity, and enables isolated testing before swapping the target path to a remote server.

**Architecture:** A cross-platform staging engine (`scripts/stage_server_bundle.py`) packages only the essential runtime artifacts (`app/`, `frontend/`, `docker-compose.yml`, `Dockerfile.*`, `requirements.txt`, `.env`) into `$DEPLOY_TARGET_DIR` and generates a verifiable `release_manifest.txt`. `scripts/deploy.sh` triggers this staging phase, allowing zero-friction switching between local testing and remote server deployment (`/opt/orderhub`). Automated tests in `tests/unit/test_deploy_staging.py` guarantee that dev files and test suites are never copied to the server directory.

**Tech Stack:** Python 3.10+, Bash / Shell, Docker Compose, Pytest.

---

### Task 1: Staging Engine Tests (`tests/unit/test_deploy_staging.py`)

**Files:**
- Create: `tests/unit/test_deploy_staging.py`

- [x] **Step 1: Write the failing tests for server staging and manifest generation**

```python
import os
import shutil
from pathlib import Path
import pytest
from scripts.stage_server_bundle import stage_server_bundle, REQUIRED_SERVER_FILES, EXCLUDED_PATTERNS

@pytest.mark.unit
class TestServerStagingEngine:
    """Validates staging of server runtime artifacts into isolated target path."""

    @pytest.fixture
    def staging_dir(self, tmp_path):
        target = tmp_path / "simulated_server" / "orderhub"
        yield target
        if target.exists():
            shutil.rmtree(target, ignore_errors=True)

    def test_staging_copies_all_required_files(self, staging_dir):
        """Verifies that all essential server files are copied to the target directory."""
        repo_root = Path(__file__).resolve().parent.parent.parent
        manifest_file = stage_server_bundle(
            repo_root=repo_root,
            target_dir=staging_dir,
            environment="uat",
            port=8000,
            frontend_port=8080,
            api_url="http://localhost:8000"
        )

        assert staging_dir.exists()
        assert manifest_file.exists()

        # Check required files exist in staged destination
        assert (staging_dir / "docker-compose.yml").is_file()
        assert (staging_dir / "Dockerfile.backend").is_file()
        assert (staging_dir / "Dockerfile.frontend").is_file()
        assert (staging_dir / "requirements.txt").is_file()
        assert (staging_dir / "app" / "main.py").is_file()
        assert (staging_dir / "frontend" / "index.html").is_file()
        assert (staging_dir / ".env").is_file()

    def test_staging_excludes_tests_and_dev_caches(self, staging_dir):
        """Verifies that tests, .git, and cache directories are not copied to the server."""
        repo_root = Path(__file__).resolve().parent.parent.parent
        stage_server_bundle(
            repo_root=repo_root,
            target_dir=staging_dir,
            environment="production",
            port=8000,
            frontend_port=8080,
            api_url="https://api.orderhub.example.com"
        )

        assert not (staging_dir / "tests").exists()
        assert not (staging_dir / ".git").exists()
        assert not (staging_dir / ".pytest_cache").exists()
        assert not (staging_dir / ".ruff_cache").exists()

    def test_release_manifest_contains_expected_entries(self, staging_dir):
        """Verifies that release_manifest.txt details staged files and sizes."""
        repo_root = Path(__file__).resolve().parent.parent.parent
        manifest_file = stage_server_bundle(
            repo_root=repo_root,
            target_dir=staging_dir,
            environment="uat",
            port=8000,
            frontend_port=8080,
            api_url="http://localhost:8000"
        )

        content = manifest_file.read_text(encoding="utf-8")
        assert "RELEASE MANIFEST" in content
        assert "Environment: uat" in content
        assert "docker-compose.yml" in content
        assert "app/main.py" in content
```

- [x] **Step 2: Run test to verify it fails before implementation**

Run: `python -m pytest tests/unit/test_deploy_staging.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'scripts.stage_server_bundle'`

- [x] **Step 3: Commit test file**

Check `.agent/config.yml` for `auto_commit` setting.
If `auto_commit: true` (default when absent):
```bash
git add tests/unit/test_deploy_staging.py
git commit -m "test: add test suite for server staging engine"
```

---

### Task 2: Implement Staging Engine (`scripts/stage_server_bundle.py`)

**Files:**
- Create: `scripts/stage_server_bundle.py`

- [x] **Step 1: Write `scripts/stage_server_bundle.py`**

```python
#!/usr/bin/env python3
"""
Server Staging & Artifact Packaging Engine
Usage: python scripts/stage_server_bundle.py --target-dir <path> --env <uat|production>
"""
import os
import sys
import shutil
import argparse
from datetime import datetime, timezone
from pathlib import Path

REQUIRED_SERVER_FILES = [
    "docker-compose.yml",
    "Dockerfile.backend",
    "Dockerfile.frontend",
    "requirements.txt",
    "app",
    "frontend",
    "scripts/smoke_test.sh",
]

EXCLUDED_PATTERNS = {
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    ".coverage",
    ".git",
    "tests",
}

def stage_server_bundle(
    repo_root: Path,
    target_dir: Path,
    environment: str = "uat",
    port: int = 8000,
    frontend_port: int = 8080,
    api_url: str = ""
) -> Path:
    """Packages runtime server files into target_dir and creates release_manifest.txt."""
    repo_root = Path(repo_root).resolve()
    target_dir = Path(target_dir).resolve()

    target_dir.mkdir(parents=True, exist_ok=True)

    manifest_lines = [
        "==================================================",
        f"ORDERHUB SERVER RELEASE MANIFEST",
        f"Environment: {environment}",
        f"Timestamp:   {datetime.now(timezone.utc).isoformat()}",
        f"Target Dir:  {target_dir}",
        "==================================================",
        "STAGED FILES:"
    ]

    # 1. Copy required files and directories
    for rel_path_str in REQUIRED_SERVER_FILES:
        src_path = repo_root / rel_path_str
        dst_path = target_dir / rel_path_str

        if not src_path.exists():
            continue

        if src_path.is_file():
            dst_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_path, dst_path)
            size = dst_path.stat().st_size
            manifest_lines.append(f"  [FILE] {rel_path_str} ({size} bytes)")
        elif src_path.is_dir():
            if dst_path.exists():
                shutil.rmtree(dst_path)
            shutil.copytree(
                src_path,
                dst_path,
                ignore=shutil.ignore_patterns(*EXCLUDED_PATTERNS)
            )
            count = sum(1 for _ in dst_path.rglob("*") if _.is_file())
            manifest_lines.append(f"  [DIR]  {rel_path_str} ({count} files)")

    # 2. Generate .env file for target environment
    env_content = f"""# OrderHub Server Configuration
APP_ENV={environment}
PORT={port}
FRONTEND_PORT={frontend_port}
API_URL={api_url}
"""
    env_file = target_dir / ".env"
    env_file.write_text(env_content, encoding="utf-8")
    manifest_lines.append(f"  [FILE] .env ({env_file.stat().st_size} bytes)")

    # 3. Write release_manifest.txt
    manifest_file = target_dir / "release_manifest.txt"
    manifest_lines.append("==================================================")
    manifest_lines.append("STATUS: READY_FOR_DEPLOYMENT")
    manifest_file.write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")

    return manifest_file

def main():
    parser = argparse.ArgumentParser(description="Stage server deployment bundle.")
    parser.add_argument("--target-dir", default="./local_server_storage/orderhub", help="Target destination path")
    parser.add_argument("--env", default="uat", choices=["uat", "production"], help="Target environment")
    parser.add_argument("--port", type=int, default=8000, help="Backend port")
    parser.add_argument("--frontend-port", type=int, default=8080, help="Frontend port")
    parser.add_argument("--api-url", default="", help="Injected API URL")

    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    manifest = stage_server_bundle(
        repo_root=repo_root,
        target_dir=Path(args.target_dir),
        environment=args.env,
        port=args.port,
        frontend_port=args.frontend_port,
        api_url=args.api_url
    )
    print(f"Server bundle successfully staged at: {Path(args.target_dir).resolve()}")
    print(f"Manifest written to: {manifest}")

if __name__ == "__main__":
    main()
```

- [x] **Step 2: Run pytest to verify staging engine tests pass**

Run: `python -m pytest tests/unit/test_deploy_staging.py`
Expected: 3 passed in < 1s

- [x] **Step 3: Commit staging engine implementation**

```bash
git add scripts/stage_server_bundle.py tests/unit/test_deploy_staging.py
git commit -m "feat: implement server staging engine and pass unit tests"
```

---

### Task 3: Enhance `scripts/deploy.sh` with Staging Phase & Configurable Target

**Files:**
- Modify: `scripts/deploy.sh`

- [x] **Step 1: Update `scripts/deploy.sh` to stage bundle before deployment**

Update `scripts/deploy.sh` to:
- Accept `DEPLOY_TARGET_DIR` (default `./local_server_storage/orderhub`).
- Run `python scripts/stage_server_bundle.py --target-dir "$DEPLOY_TARGET_DIR" --env "$ENVIRONMENT"`.
- Output the staged path and manifest summary.
- In dry-run mode, simulate deployment from the staged path.
- In live mode, execute Docker Compose commands directly from within `$DEPLOY_TARGET_DIR`.

- [x] **Step 2: Test `scripts/deploy.sh` in dry-run and staging mode**

Run: `bash scripts/deploy.sh uat`
Expected: Successfully stages into `./local_server_storage/orderhub` and prints manifest.

- [x] **Step 3: Commit `scripts/deploy.sh` update**

```bash
git add scripts/deploy.sh
git commit -m "feat(deploy): integrate local server staging and configurable DEPLOY_TARGET_DIR"
```

---

### Task 4: Documentation Update in `docs/PIPELINE.md`

**Files:**
- Modify: `docs/PIPELINE.md`

- [x] **Step 1: Document local staging, file requirements, and switching to remote server**

Add Section 2.1 in `docs/PIPELINE.md`:
- Explaining the exact server file manifest.
- How to test locally via `DEPLOY_TARGET_DIR="./local_server_storage/orderhub"`.
- How to switch `DEPLOY_TARGET_DIR` to the real server path (`/opt/orderhub` or SSH/SCP).

- [x] **Step 2: Commit `docs/PIPELINE.md`**

```bash
git add docs/PIPELINE.md
git commit -m "docs: document server staging workflow and target path configuration"
```

---

### Task 5: End-to-End Verification & Remote Push

**Files:**
- Modify: `docs/superpowers/plans/2026-10-21-local-server-staging-deploy.md` (check off all boxes)

- [x] **Step 1: Run full test suite with coverage gate**

Run: `python -m pytest tests/ --cov=app --cov-fail-under=80`
Expected: All tests pass (26/26 tests, >= 80% coverage).

- [x] **Step 2: Commit plan checklist and push to remote `uat`**

```bash
git add docs/superpowers/plans/2026-10-21-local-server-staging-deploy.md
git commit -m "docs: complete local server staging plan"
git push origin uat
```
