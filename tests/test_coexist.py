import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from wechat_ipa_audit.coexist import inspect_coexist, make_coexist_ipa


class CoexistPackagingTests(unittest.TestCase):
    def test_rewrites_identity_and_strips_extension_signing_surface(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.ipa"
            output = root / "coexist.ipa"
            main_info = {
                "CFBundleIdentifier": "com.tencent.xin",
                "CFBundleExecutable": "WeChat",
                "CFBundleDisplayName": "微信",
                "CFBundleURLTypes": [
                    {"CFBundleURLSchemes": ["wechat", "weixin", "prefs"]}
                ],
            }
            extension_info = {
                "CFBundleIdentifier": "com.tencent.xin.sharetimeline",
                "CFBundleExecutable": "Share",
            }
            with zipfile.ZipFile(source, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr(
                    "Payload/WeChat.app/Info.plist",
                    plistlib.dumps(main_info),
                )
                archive.writestr("Payload/WeChat.app/WeChat", b"main")
                archive.writestr(
                    "Payload/WeChat.app/Frameworks/WeChatMods.dylib",
                    b"loader",
                )
                archive.writestr(
                    "Payload/WeChat.app/_CodeSignature/CodeResources",
                    b"stale",
                )
                archive.writestr(
                    "Payload/WeChat.app/embedded.mobileprovision",
                    b"stale-profile",
                )
                archive.writestr(
                    "Payload/WeChat.app/PlugIns/Share.appex/Info.plist",
                    plistlib.dumps(extension_info),
                )
                archive.writestr(
                    "Payload/WeChat.app/PlugIns/Share.appex/Share",
                    b"extension",
                )
                archive.writestr(
                    "Payload/WeChat.app/Watch/Watch.app/Watch",
                    b"watch",
                )

            make_coexist_ipa(
                source,
                output,
                bundle_id="com.luvsic73.wechatmods",
                display_name="微信 Glass",
                scheme_prefix="wechatmods",
                strip_extensions=True,
            )

            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                rewritten = plistlib.loads(
                    archive.read("Payload/WeChat.app/Info.plist")
                )
            inspection = inspect_coexist(output)

        self.assertEqual(
            rewritten["CFBundleIdentifier"],
            "com.luvsic73.wechatmods",
        )
        self.assertEqual(rewritten["CFBundleDisplayName"], "微信 Glass")
        self.assertEqual(
            rewritten["CFBundleURLTypes"][0]["CFBundleURLSchemes"],
            [
                "wechatmods-wechat",
                "wechatmods-weixin",
                "wechatmods-prefs",
            ],
        )
        self.assertIn("Payload/WeChat.app/WeChat", names)
        self.assertIn(
            "Payload/WeChat.app/Frameworks/WeChatMods.dylib",
            names,
        )
        self.assertFalse(any("/PlugIns/" in name for name in names))
        self.assertFalse(any("/Watch/" in name for name in names))
        self.assertFalse(any("/_CodeSignature/" in name for name in names))
        self.assertFalse(
            any(name.endswith("embedded.mobileprovision") for name in names)
        )
        self.assertTrue(inspection["coexist_ready"])
        self.assertEqual(inspection["extensions"], [])
        self.assertEqual(inspection["signing_residue"], [])


if __name__ == "__main__":
    unittest.main()
