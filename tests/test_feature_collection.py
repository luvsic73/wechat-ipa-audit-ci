import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from wechat_ipa_audit.feature_collection import (
    ORIGINAL_SHA256,
    PATCH_SPECS,
    PATCHED_SHA256,
    repair_feature_collection,
)


class FeatureCollectionRepairTests(unittest.TestCase):
    def test_removes_only_pinned_identity_and_vendor_nuisance_entries(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "MiYou.dylib"
            output = root / "MiYou.repaired.dylib"
            final_offset = max(
                patch["file_offset"] + len(patch["before"])
                for patch in PATCH_SPECS
            )
            payload = bytearray(final_offset + 16)
            for patch in PATCH_SPECS:
                start = patch["file_offset"]
                payload[start:start + len(patch["before"])] = patch["before"]
            source.write_bytes(payload)

            report = repair_feature_collection(
                source,
                output,
                expected_input_sha256=hashlib.sha256(payload).hexdigest(),
                expected_output_sha256=None,
            )

            patched = output.read_bytes()

        expected = bytearray(payload)
        for patch in PATCH_SPECS:
            start = patch["file_offset"]
            expected[start:start + len(patch["after"])] = patch["after"]
            self.assertEqual(
                patched[start:start + len(patch["after"])],
                patch["after"],
            )
        self.assertEqual(patched, bytes(expected))
        self.assertEqual(
            [patch["effect"] for patch in report["patches"]],
            [
                "disable identity and environment rewrite constructor",
                "remove embedded signature or expiry reminder",
                "remove author authorization settings section",
                "remove follow-author browser action",
                "treat author follow gate as satisfied",
            ],
        )

    def test_project_hashes_are_pinned(self) -> None:
        root = Path(__file__).resolve().parents[1]
        catalog = json.loads(
            (root / "data" / "modules.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            ORIGINAL_SHA256,
            "846829A8351934AA805F4A77BE59E11DB6424FED53AD151758C8B4EFB480835F",
        )
        self.assertEqual(
            PATCHED_SHA256,
            "69B4858E15269772CE4C15ADC2E3372C10C468AC42ED9149E84243BCF57F0C91",
        )
        self.assertEqual(
            catalog["feature_collection"]["full_sha256"],
            PATCHED_SHA256,
        )

    def test_rejects_an_unknown_constructor_layout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "MiYou.dylib"
            output = root / "MiYou.repaired.dylib"
            source.write_bytes(
                b"\0" * (
                    max(patch["file_offset"] for patch in PATCH_SPECS) + 16
                )
            )

            with self.assertRaisesRegex(
                ValueError,
                "pinned patch entry instruction",
            ):
                repair_feature_collection(
                    source,
                    output,
                    expected_input_sha256=None,
                    expected_output_sha256=None,
                )
