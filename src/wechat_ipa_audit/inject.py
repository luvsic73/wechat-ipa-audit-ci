from __future__ import annotations

import plistlib
import shutil
import tempfile
import zipfile
from collections.abc import Callable
from pathlib import Path


LOADER_NAME = "WeChatMods.dylib"
LOADER_INSTALL_NAME = f"@executable_path/Frameworks/{LOADER_NAME}"


def _app_paths(archive: zipfile.ZipFile) -> tuple[str, str, str]:
    info_paths = sorted(
        name
        for name in archive.namelist()
        if name.startswith("Payload/")
        and name.count("/") == 2
        and name.endswith(".app/Info.plist")
    )
    if len(info_paths) != 1:
        raise ValueError("package must contain one top-level app Info.plist")
    info_path = info_paths[0]
    app_prefix = info_path[: -len("Info.plist")]
    info = plistlib.loads(archive.read(info_path))
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or not executable:
        raise ValueError("top-level Info.plist has no CFBundleExecutable")
    return app_prefix, app_prefix + executable, app_prefix + "Frameworks/" + LOADER_NAME


def _lief_patch(binary_path: Path, install_name: str) -> None:
    try:
        import lief
    except ImportError as error:
        raise RuntimeError("LIEF is required for Mach-O loader injection") from error

    parsed = lief.MachO.parse(str(binary_path))
    if parsed is None:
        raise ValueError(f"LIEF did not recognize Mach-O: {binary_path}")
    binaries = list(parsed)
    if not binaries:
        raise ValueError(f"Mach-O has no slices: {binary_path}")
    for binary in binaries:
        names = {library.name for library in binary.libraries}
        if install_name not in names:
            binary.add_library(install_name)
    parsed.write(str(binary_path))


def inject_loader(
    input_ipa: str | Path,
    loader: str | Path,
    output_ipa: str | Path,
    *,
    patch_binary: Callable[[Path, str], None] | None = None,
) -> None:
    input_path = Path(input_ipa).resolve()
    loader_path = Path(loader).resolve()
    output_path = Path(output_ipa).resolve()
    if input_path == output_path:
        raise ValueError("input and output IPA paths must differ")
    if not loader_path.is_file():
        raise FileNotFoundError(loader_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    patch = patch_binary or _lief_patch

    with zipfile.ZipFile(input_path) as source:
        app_prefix, executable_member, loader_member = _app_paths(source)
        signature_prefix = app_prefix + "_CodeSignature/"
        with tempfile.TemporaryDirectory() as directory:
            executable_path = Path(directory) / "main"
            with source.open(executable_member) as input_stream:
                with executable_path.open("wb") as output_stream:
                    shutil.copyfileobj(input_stream, output_stream, length=1024 * 1024)
            patch(executable_path, LOADER_INSTALL_NAME)
            patched_executable = executable_path.read_bytes()

        with zipfile.ZipFile(
            output_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
        ) as target:
            for member in source.infolist():
                if member.filename == loader_member or member.filename.startswith(
                    signature_prefix
                ):
                    continue
                if member.filename == executable_member:
                    target.writestr(member, patched_executable)
                    continue
                with source.open(member) as input_stream:
                    with target.open(member, "w") as output_stream:
                        shutil.copyfileobj(
                            input_stream,
                            output_stream,
                            length=1024 * 1024,
                        )

            loader_info = zipfile.ZipInfo(loader_member)
            loader_info.create_system = 3
            loader_info.external_attr = 0o100755 << 16
            loader_info.compress_type = zipfile.ZIP_DEFLATED
            with loader_path.open("rb") as input_stream:
                with target.open(loader_info, "w") as output_stream:
                    shutil.copyfileobj(
                        input_stream,
                        output_stream,
                        length=1024 * 1024,
                    )
