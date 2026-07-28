import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from wechat_ipa_audit.account_safety import assess_account_safety


def _write_ipa(
    path: Path,
    *,
    bundle_id: str,
    main: bytes = b"official-main",
    extra: dict[str, bytes] | None = None,
) -> None:
    info = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleExecutable": "WeChat",
        "CFBundleDisplayName": "Fixture",
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(
            "Payload/WeChat.app/Info.plist",
            plistlib.dumps(info),
        )
        archive.writestr("Payload/WeChat.app/WeChat", main)
        for name, data in (extra or {}).items():
            archive.writestr(name, data)


class AccountSafetyTests(unittest.TestCase):
    def test_allows_identity_consistent_candidate_without_tampering(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.ipa"
            candidate = root / "candidate.ipa"
            _write_ipa(baseline, bundle_id="com.tencent.xin")
            _write_ipa(
                candidate,
                bundle_id="com.tencent.xin",
                extra={
                    "Payload/WeChat.app/Frameworks/WeChatMods.dylib":
                        b"benign-ui-and-message-hooks"
                },
            )

            report = assess_account_safety(baseline, candidate)

        self.assertTrue(report["identity_consistent"])
        self.assertFalse(report["release_blocked"])
        self.assertEqual(report["forbidden_marker_hits"], [])
        self.assertEqual(
            report["added_executable_components"],
            ["Payload/WeChat.app/Frameworks/WeChatMods.dylib"],
        )

    def test_blocks_coexist_identity_change(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.ipa"
            candidate = root / "candidate.ipa"
            _write_ipa(baseline, bundle_id="com.tencent.xin")
            _write_ipa(
                candidate,
                bundle_id="com.example.coexist",
            )

            report = assess_account_safety(baseline, candidate)

        self.assertFalse(report["identity_consistent"])
        self.assertTrue(report["release_blocked"])
        self.assertIn(
            "bundle_identity_changed",
            {finding["code"] for finding in report["findings"]},
        )

    def test_blocks_auth_and_environment_tampering_in_added_component(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / "baseline.ipa"
            candidate = root / "candidate.ipa"
            _write_ipa(
                baseline,
                bundle_id="com.tencent.xin",
                main=b"ManualAuthAesReqData exists in the official main",
            )
            _write_ipa(
                candidate,
                bundle_id="com.tencent.xin",
                main=b"ManualAuthAesReqData exists in the official main",
                extra={
                    "Payload/WeChat.app/xnsp.dylib":
                        b"setBundleId: setClientSeqId: JailBreakHelper"
                },
            )

            report = assess_account_safety(baseline, candidate)

        self.assertTrue(report["release_blocked"])
        self.assertEqual(
            {hit["marker"] for hit in report["forbidden_marker_hits"]},
            {"setBundleId:", "setClientSeqId:", "JailBreakHelper"},
        )
        self.assertNotIn(
            "ManualAuthAesReqData",
            {hit["marker"] for hit in report["forbidden_marker_hits"]},
        )

    def test_coexist_build_runs_fail_closed_account_safety_gate(self) -> None:
        root = Path(__file__).resolve().parents[1]
        for name in ("build-iloader.ps1", "build-coexist.ps1"):
            script = (root / "scripts" / name).read_text(encoding="utf-8")
            self.assertIn("account-safety", script)
            self.assertIn("$BaseIpa $outputPath", script)
            self.assertIn(
                "Remove-Item -LiteralPath $outputPath",
                script,
            )

    def test_runtime_hook_policy_names_account_identity_boundaries(
        self,
    ) -> None:
        source = (
            Path(__file__).resolve().parents[1]
            / "ios"
            / "WeChatMods"
            / "WMModuleDescriptor.m"
        ).read_text(encoding="utf-8")

        for marker in (
            "ManualAuthAesReqData",
            "setBundleId:",
            "setClientSeqId:",
            "setDeviceName:",
            "JailBreakHelper",
        ):
            self.assertIn(marker, source)


if __name__ == "__main__":
    unittest.main()
