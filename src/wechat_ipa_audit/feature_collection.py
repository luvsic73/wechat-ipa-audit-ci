from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any


ORIGINAL_SHA256 = (
    "846829A8351934AA805F4A77BE59E11DB6424FED53AD151758C8B4EFB480835F"
)
PATCHED_SHA256 = (
    "949867747FE5189212FAA3B28137157220BA7B40D77A94404A205F45B61565E1"
)
RISKY_CONSTRUCTOR_VIRTUAL_ADDRESS = 0xA600A0
RISKY_CONSTRUCTOR_FILE_OFFSET = 0xA600A0
ORIGINAL_ENTRY_INSTRUCTION = bytes.fromhex("FC6FBAA9")
PATCHED_ENTRY_INSTRUCTION = bytes.fromhex("C0035FD6")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def repair_feature_collection(
    source: str | Path,
    output: str | Path,
    *,
    expected_input_sha256: str | None = ORIGINAL_SHA256,
    expected_output_sha256: str | None = PATCHED_SHA256,
) -> dict[str, Any]:
    source_path = Path(source).resolve()
    output_path = Path(output).resolve()
    payload = bytearray(source_path.read_bytes())
    input_sha256 = _sha256(payload)
    if (
        expected_input_sha256 is not None
        and input_sha256 != expected_input_sha256.upper()
    ):
        raise ValueError(
            "feature collection input SHA-256 does not match the audited sample"
        )

    start = RISKY_CONSTRUCTOR_FILE_OFFSET
    end = start + len(ORIGINAL_ENTRY_INSTRUCTION)
    if payload[start:end] != ORIGINAL_ENTRY_INSTRUCTION:
        raise ValueError(
            "feature collection constructor entry instruction does not match"
        )
    payload[start:end] = PATCHED_ENTRY_INSTRUCTION
    output_sha256 = _sha256(payload)
    if (
        expected_output_sha256 is not None
        and output_sha256 != expected_output_sha256.upper()
    ):
        raise ValueError(
            "feature collection output SHA-256 does not match the pinned repair"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(payload)
    return {
        "schema_version": 1,
        "source": str(source_path),
        "output": str(output_path),
        "input_sha256": input_sha256,
        "output_sha256": output_sha256,
        "patch": {
            "virtual_address": hex(RISKY_CONSTRUCTOR_VIRTUAL_ADDRESS),
            "file_offset": hex(RISKY_CONSTRUCTOR_FILE_OFFSET),
            "before": ORIGINAL_ENTRY_INSTRUCTION.hex().upper(),
            "after": PATCHED_ENTRY_INSTRUCTION.hex().upper(),
            "effect": (
                "disable constructor 17 identity and environment rewrites"
            ),
        },
    }
