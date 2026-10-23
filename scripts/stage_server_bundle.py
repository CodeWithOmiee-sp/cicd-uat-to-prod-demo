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
    "config",
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
    parser.add_argument("--api-url", default="", nargs="?", const="", help="Injected API URL")

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
