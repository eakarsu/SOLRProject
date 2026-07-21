"""Dependency-free PEP 517 wheel builder for the supported control plane."""

from __future__ import annotations

import base64
import hashlib
import os
from pathlib import Path
import zipfile


NAME = "solrproject_control_plane"
VERSION = "1.0.0"
DIST_INFO = f"{NAME}-{VERSION}.dist-info"


def get_requires_for_build_wheel(config_settings=None):
    return []


def get_requires_for_build_sdist(config_settings=None):
    return []


def _metadata() -> dict[str, bytes]:
    return {
        f"{DIST_INFO}/METADATA": (
            "Metadata-Version: 2.4\n"
            "Name: solrproject-control-plane\n"
            f"Version: {VERSION}\n"
            "Summary: Safe, durable control plane for the quarantined SOLRProject archive\n"
            "Requires-Python: >=3.12\n"
            "License-Expression: LicenseRef-Proprietary\n\n"
        ).encode(),
        f"{DIST_INFO}/WHEEL": (
            "Wheel-Version: 1.0\nGenerator: solrproject-stdlib-backend\n"
            "Root-Is-Purelib: true\nTag: py3-none-any\n"
        ).encode(),
        f"{DIST_INFO}/entry_points.txt": (
            "[console_scripts]\nsolrproject = discovery.cli:main\n"
        ).encode(),
    }


def _record_line(path: str, data: bytes) -> str:
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
    return f"{path},sha256={digest},{len(data)}"


def _write(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, (2026, 7, 19, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    archive.writestr(info, data)


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    root = Path(__file__).resolve().parent
    files: dict[str, bytes] = {}
    for path in sorted((root / "discovery").rglob("*.py")):
        files[path.relative_to(root).as_posix()] = path.read_bytes()
    files.update(_metadata())
    records = [_record_line(path, data) for path, data in sorted(files.items())]
    record_name = f"{DIST_INFO}/RECORD"
    files[record_name] = ("\n".join(records) + f"\n{record_name},,\n").encode()
    output = Path(wheel_directory)
    output.mkdir(parents=True, exist_ok=True)
    filename = f"{NAME}-{VERSION}-py3-none-any.whl"
    with zipfile.ZipFile(output / filename, "w") as archive:
        for path, data in sorted(files.items()):
            _write(archive, path, data)
    return filename


def prepare_metadata_for_build_wheel(metadata_directory, config_settings=None):
    target = Path(metadata_directory) / DIST_INFO
    target.mkdir(parents=True, exist_ok=True)
    for path, data in _metadata().items():
        (target / Path(path).name).write_bytes(data)
    return DIST_INFO

