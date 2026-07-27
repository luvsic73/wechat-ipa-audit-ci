import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from test_audit import make_ipa
from wechat_ipa_audit.packaging import package_all_disabled, verify_package


class PackagingTests(unittest.TestCase):
    def test_packages_a_manifest_with_every_module_disabled(self) -> None:
        modules = [
            {"id": "anti-revoke", "risk": "medium"},
            {"id": "theme", "risk": "low"},
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / "base.ipa"
            output = root / "output.ipa"
            make_ipa(base)

            package_all_disabled(base, output, modules)

            with zipfile.ZipFile(output) as archive:
                manifest = json.loads(
                    archive.read(
                        "Payload/Fixture.app/WeChatMods/module-manifest.json"
                    )
                )
            verification = verify_package(output)

        self.assertEqual(
            manifest["modules"],
            [
                {"enabled": False, "id": "anti-revoke", "risk": "medium"},
                {"enabled": False, "id": "theme", "risk": "low"},
            ],
        )
        self.assertTrue(verification["valid"])
        self.assertEqual(verification["enabled_modules"], [])

