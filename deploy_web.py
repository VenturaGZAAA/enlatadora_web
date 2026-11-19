#!/usr/bin/env python3
"""
Deploy Flutter Web to SD card / target directory.
Cross-platform deployment script in Python.
"""

import argparse
import gzip
import os
import pathlib
import shutil
import subprocess
import sys

EXCLUDED_EXTENSIONS = {
    ".br",
    ".gz",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".svg",
    ".webp",
    ".woff",
    ".woff2",
}


def clean_build_dir(build_web_path: pathlib.Path) -> None:
    """Remove existing build/web directory if present."""
    if build_web_path.exists():
        print(f"Cleaning existing build directory at {build_web_path}...")
        shutil.rmtree(build_web_path)


def build_flutter_web(project_root: pathlib.Path) -> None:
    """Run flutter build web --release."""
    print("Building Flutter web app...")
    flutter_cmd = shutil.which("flutter") or "flutter"
    config_file = project_root / "environment" / "config_esp.json"

    cmd = [
        flutter_cmd,
        "build",
        "web",
        "--release",
        f"--dart-define-from-file={config_file}",
    ]

    use_shell = sys.platform == "win32"
    result = subprocess.run(cmd, cwd=project_root, shell=use_shell)
    if result.returncode != 0:
        print("❌ Flutter build failed.", file=sys.stderr)
        sys.exit(result.returncode)


def compress_with_gzip(build_web_path: pathlib.Path) -> None:
    """Compress eligible static assets with gzip (max compression)."""
    print("Compressing files with gzip...")
    compressed_count = 0

    for file_path in build_web_path.rglob("*"):
        if not file_path.is_file():
            continue

        if file_path.suffix.lower() in EXCLUDED_EXTENSIONS:
            continue

        gz_path = file_path.with_name(file_path.name + ".gz")
        if not gz_path.exists():
            with open(file_path, "rb") as f_in:
                with gzip.open(gz_path, "wb", compresslevel=9) as f_out:
                    shutil.copyfileobj(f_in, f_out)
            rel_path = gz_path.relative_to(build_web_path)
            print(f"  Gzip: {rel_path}")
            compressed_count += 1

    print(f"Compressed {compressed_count} file(s).")


def sync_to_destination(build_web_path: pathlib.Path, destination: pathlib.Path) -> None:
    """Copy build/web contents to the destination directory."""
    # Handle whether destination already includes '/web' or is the root directory
    if destination.name.lower() == "web":
        target_web_dir = destination
    else:
        target_web_dir = destination / "web"

    print(f"Syncing build assets to {target_web_dir}...")
    target_web_dir.mkdir(parents=True, exist_ok=True)

    # Clean existing target directory contents to ensure stale files are removed
    for item in target_web_dir.iterdir():
        if item.is_dir():
            shutil.rmtree(item)
        else:
            item.unlink()

    # Copy new build assets
    shutil.copytree(build_web_path, target_web_dir, dirs_exist_ok=True)
    print("✅ Deployment complete.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build Flutter web app, compress assets with gzip, and deploy to destination."
    )
    parser.add_argument(
        "destination",
        type=pathlib.Path,
        help="Path to the destination directory (e.g. SD card path like /run/media/.../CanningMachine or E:\\CanningMachine)",
    )

    args = parser.parse_args()

    project_root = pathlib.Path(__file__).resolve().parent
    build_web_path = project_root / "build" / "web"

    clean_build_dir(build_web_path)
    build_flutter_web(project_root)
    compress_with_gzip(build_web_path)
    sync_to_destination(build_web_path, args.destination)


if __name__ == "__main__":
    main()
