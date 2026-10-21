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
        assert "app" in content
