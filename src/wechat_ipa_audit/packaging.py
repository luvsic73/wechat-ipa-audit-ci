from __future__ import annotations

import json
import plistlib
import re
import shutil
import zipfile
from pathlib import Path
from typing import Any


_TOP_LEVEL_INFO = re.compile(r"^Payload/[^/]+\.app/Info\.plist$")


def _manifest_path(archive: zipfile.ZipFile) -> str:
    infos = sorted(name for name in archive.namelist() if _TOP_LEVEL_INFO.match(name))
    if len(infos) != 1:
        raise ValueError("package must contain one top-level app Info.plist")
    return infos[0][: -len("Info.plist")] + "WeChatMods/module-manifest.json"


def package_all_disabled(
    base_ipa: str | Path,
    output_ipa: str | Path,
    modules: list[dict[str, Any]],
) -> None:
    base_path = Path(base_ipa)
    output_path = Path(output_ipa)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(base_path) as source:
        manifest_path = _manifest_path(source)
        manifest = {
            "schema_version": 1,
            "activation": "restart-required",
            "safe_mode_crash_threshold": 2,
            "modules": [
                {
                    **{key: value for key, value in module.items() if key != "enabled"},
                    "enabled": False,
                }
                for module in modules
            ],
        }
        with zipfile.ZipFile(
            output_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
        ) as target:
            for member in source.infolist():
                if member.filename == manifest_path:
                    continue
                with source.open(member) as input_stream:
                    with target.open(member, "w") as output_stream:
                        shutil.copyfileobj(
                            input_stream,
                            output_stream,
                            length=1024 * 1024,
                        )
            target.writestr(
                manifest_path,
                json.dumps(
                    manifest,
                    ensure_ascii=False,
                    indent=2,
                    sort_keys=True,
                ).encode("utf-8"),
            )


def verify_package(path: str | Path) -> dict[str, Any]:
    with zipfile.ZipFile(path) as archive:
        manifest_path = _manifest_path(archive)
        manifest = json.loads(archive.read(manifest_path))
        app_prefix = manifest_path.split("WeChatMods/", 1)[0]
        info_path = app_prefix + "Info.plist"
        loader_path = app_prefix + "Frameworks/WeChatMods.dylib"
        plistlib.loads(archive.read(info_path))
        loader_present = loader_path in archive.namelist()
        loader_executable = loader_present and bool(
            (archive.getinfo(loader_path).external_attr >> 16) & 0o111
        )
    modules = manifest.get("modules", [])
    enabled = sorted(
        module["id"] for module in modules if module.get("enabled") is True
    )
    return {
        "valid": not enabled and loader_present and loader_executable,
        "manifest_path": manifest_path,
        "module_count": len(modules),
        "enabled_modules": enabled,
        "loader_present": loader_present,
        "loader_executable": loader_executable,
    }
