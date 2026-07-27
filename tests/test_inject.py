import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from wechat_ipa_audit.inject import LOADER_INSTALL_NAME, inject_loader


class InjectTests(unittest.TestCase):
    def test_injects_loader_and_removes_stale_top_level_signature(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.ipa"
            loader = root / "WeChatMods.dylib"
            output = root / "output.ipa"
            loader.write_bytes(b"loader")
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr(
                    "Payload/Fixture.app/Info.plist",
                    plistlib.dumps({"CFBundleExecutable": "Fixture"}),
                )
                archive.writestr("Payload/Fixture.app/Fixture", b"main")
                archive.writestr(
                    "Payload/Fixture.app/_CodeSignature/CodeResources", b"stale"
                )
                archive.writestr(
                    "Payload/Fixture.app/PlugIns/Share.appex/Share", b"extension"
                )

            def fake_patch(path: Path, install_name: str) -> None:
                self.assertEqual(install_name, LOADER_INSTALL_NAME)
                path.write_bytes(path.read_bytes() + b"|patched|")

            inject_loader(source, loader, output, patch_binary=fake_patch)

            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                main = archive.read("Payload/Fixture.app/Fixture")
                added_loader = archive.read(
                    "Payload/Fixture.app/Frameworks/WeChatMods.dylib"
                )
                loader_mode = (
                    archive.getinfo(
                        "Payload/Fixture.app/Frameworks/WeChatMods.dylib"
                    ).external_attr
                    >> 16
                )

        self.assertEqual(main, b"main|patched|")
        self.assertEqual(added_loader, b"loader")
        self.assertNotIn(
            "Payload/Fixture.app/_CodeSignature/CodeResources", names
        )
        self.assertIn("Payload/Fixture.app/PlugIns/Share.appex/Share", names)
        self.assertEqual(loader_mode & 0o111, 0o111)


if __name__ == "__main__":
    unittest.main()
