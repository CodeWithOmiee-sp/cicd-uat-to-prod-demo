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
