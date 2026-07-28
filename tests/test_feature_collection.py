import hashlib
import tempfile
import unittest
from pathlib import Path

from wechat_ipa_audit.feature_collection import (
    ORIGINAL_ENTRY_INSTRUCTION,
    ORIGINAL_SHA256,
    PATCHED_ENTRY_INSTRUCTION,
    PATCHED_SHA256,
    RISKY_CONSTRUCTOR_FILE_OFFSET,
    repair_feature_collection,
)


class FeatureCollectionRepairTests(unittest.TestCase):
    def test_replaces_only_the_identity_constructor_entry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "MiYou.dylib"
            output = root / "MiYou.repaired.dylib"
            payload = bytearray(RISKY_CONSTRUCTOR_FILE_OFFSET + 16)
            payload[
                RISKY_CONSTRUCTOR_FILE_OFFSET:
                RISKY_CONSTRUCTOR_FILE_OFFSET + 4
            ] = ORIGINAL_ENTRY_INSTRUCTION
            source.write_bytes(payload)

            report = repair_feature_collection(
                source,
                output,
                expected_input_sha256=hashlib.sha256(payload).hexdigest(),
                expected_output_sha256=None,
            )

            patched = output.read_bytes()

        self.assertEqual(
            patched[
                RISKY_CONSTRUCTOR_FILE_OFFSET:
                RISKY_CONSTRUCTOR_FILE_OFFSET + 4
            ],
            PATCHED_ENTRY_INSTRUCTION,
        )
        self.assertEqual(
            patched[:RISKY_CONSTRUCTOR_FILE_OFFSET],
            bytes(payload[:RISKY_CONSTRUCTOR_FILE_OFFSET]),
        )
        self.assertEqual(
            patched[RISKY_CONSTRUCTOR_FILE_OFFSET + 4:],
            bytes(payload[RISKY_CONSTRUCTOR_FILE_OFFSET + 4:]),
        )
        self.assertEqual(
            report["patch"]["effect"],
            "disable constructor 17 identity and environment rewrites",
        )

    def test_project_hashes_are_pinned(self) -> None:
        self.assertEqual(
            ORIGINAL_SHA256,
            "846829A8351934AA805F4A77BE59E11DB6424FED53AD151758C8B4EFB480835F",
        )
        self.assertEqual(
            PATCHED_SHA256,
            "949867747FE5189212FAA3B28137157220BA7B40D77A94404A205F45B61565E1",
        )

    def test_rejects_an_unknown_constructor_layout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "MiYou.dylib"
            output = root / "MiYou.repaired.dylib"
            source.write_bytes(
                b"\0" * (RISKY_CONSTRUCTOR_FILE_OFFSET + 16)
            )

            with self.assertRaisesRegex(
                ValueError,
                "constructor entry instruction",
            ):
                repair_feature_collection(
                    source,
                    output,
                    expected_input_sha256=None,
                    expected_output_sha256=None,
                )
