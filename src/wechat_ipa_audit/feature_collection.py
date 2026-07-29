from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any


ORIGINAL_SHA256 = (
    "846829A8351934AA805F4A77BE59E11DB6424FED53AD151758C8B4EFB480835F"
)
PATCHED_SHA256 = (
    "69B4858E15269772CE4C15ADC2E3372C10C468AC42ED9149E84243BCF57F0C91"
)
_RET = bytes.fromhex("C0035FD6")
_RETURN_TRUE = bytes.fromhex("20008052C0035FD6")
PATCH_SPECS = (
    {
        "name": "identity-environment-constructor",
        "virtual_address": 0xA600A0,
        "file_offset": 0xA600A0,
        "before": bytes.fromhex("FC6FBAA9"),
        "after": _RET,
        "effect": "disable identity and environment rewrite constructor",
    },
    {
        "name": "embedded-signature-reminder",
        "virtual_address": 0x1156D8,
        "file_offset": 0x1156D8,
        "before": bytes.fromhex("E923B96D"),
        "after": _RET,
        "effect": "remove embedded signature or expiry reminder",
    },
    {
        "name": "author-authorization-section",
        "virtual_address": 0x924890,
        "file_offset": 0x924890,
        "before": bytes.fromhex("FC6FBAA9"),
        "after": _RET,
        "effect": "remove author authorization settings section",
    },
    {
        "name": "follow-author-action",
        "virtual_address": 0x927ABC,
        "file_offset": 0x927ABC,
        "before": bytes.fromhex("FF8303D1"),
        "after": _RET,
        "effect": "remove follow-author browser action",
    },
    {
        "name": "follow-author-gate",
        "virtual_address": 0xA08398,
        "file_offset": 0xA08398,
        "before": bytes.fromhex("FC6FBAA9FA6701A9"),
        "after": _RETURN_TRUE,
        "effect": "treat author follow gate as satisfied",
    },
)


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

    applied_patches: list[dict[str, str]] = []
    for patch in PATCH_SPECS:
        start = patch["file_offset"]
        before = patch["before"]
        after = patch["after"]
        end = start + len(before)
        if payload[start:end] != before:
            raise ValueError(
                "feature collection pinned patch entry instruction "
                f"does not match: {patch['name']}"
            )
        payload[start:end] = after
        applied_patches.append(
            {
                "name": patch["name"],
                "virtual_address": hex(patch["virtual_address"]),
                "file_offset": hex(start),
                "before": before.hex().upper(),
                "after": after.hex().upper(),
                "effect": patch["effect"],
            }
        )
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
        "patches": applied_patches,
    }
