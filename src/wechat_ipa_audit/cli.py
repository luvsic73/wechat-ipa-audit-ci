from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .account_safety import assess_account_safety
from .app_icon import replace_app_icon
from .audit import audit_ipa
from .coexist import inspect_coexist, make_coexist_ipa
from .deep_scan import scan_ipa_members
from .diffing import diff_reports
from .inventory import select_current_targets
from .inject import inject_loader
from .packaging import package_all_disabled, verify_package


def _read_json(path: str | Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _write_json(data: Any, path: str | Path | None) -> None:
    rendered = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)
    if path:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="wechat-ipa-audit")
    commands = parser.add_subparsers(dest="command", required=True)

    audit = commands.add_parser("audit")
    audit.add_argument("ipa")
    audit.add_argument("--output")

    diff = commands.add_parser("diff")
    diff.add_argument("baseline_report")
    diff.add_argument("candidate_report")
    diff.add_argument("--output")

    inventory = commands.add_parser("inventory")
    inventory.add_argument("manifest")
    inventory.add_argument("--stable", required=True)
    inventory.add_argument("--output")

    deep_scan = commands.add_parser("deep-scan")
    deep_scan.add_argument("ipa")
    deep_scan.add_argument("--diff", required=True)
    deep_scan.add_argument("--extract-directory")
    deep_scan.add_argument("--output")

    package = commands.add_parser("package")
    package.add_argument("base_ipa")
    package.add_argument("output_ipa")
    package.add_argument("--modules", required=True)

    inject = commands.add_parser("inject")
    inject.add_argument("input_ipa")
    inject.add_argument("loader")
    inject.add_argument("output_ipa")

    coexist = commands.add_parser("coexist")
    coexist.add_argument("input_ipa")
    coexist.add_argument("output_ipa")
    coexist.add_argument("--bundle-id", required=True)
    coexist.add_argument("--display-name", default="微信 Glass")
    coexist.add_argument("--scheme-prefix", default="wechatmods")
    coexist.add_argument("--keep-extensions", action="store_true")
    coexist.add_argument("--report")

    icon = commands.add_parser("icon")
    icon.add_argument("input_ipa")
    icon.add_argument("master_png")
    icon.add_argument("icon_document")
    icon.add_argument("output_ipa")
    icon.add_argument("--report")

    account_safety = commands.add_parser("account-safety")
    account_safety.add_argument("baseline_ipa")
    account_safety.add_argument("candidate_ipa")
    account_safety.add_argument("--output")

    verify = commands.add_parser("verify")
    verify.add_argument("ipa")
    verify.add_argument("--output")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "audit":
        _write_json(audit_ipa(args.ipa), args.output)
    elif args.command == "diff":
        result = diff_reports(
            _read_json(args.baseline_report),
            _read_json(args.candidate_report),
        )
        _write_json(result, args.output)
    elif args.command == "inventory":
        manifest = _read_json(args.manifest)
        _write_json(
            select_current_targets(manifest["samples"], stable_version=args.stable),
            args.output,
        )
    elif args.command == "deep-scan":
        diff = _read_json(args.diff)
        _write_json(
            scan_ipa_members(
                args.ipa,
                diff["added"],
                extract_directory=args.extract_directory,
            ),
            args.output,
        )
    elif args.command == "package":
        modules = _read_json(args.modules)["modules"]
        package_all_disabled(args.base_ipa, args.output_ipa, modules)
    elif args.command == "inject":
        inject_loader(args.input_ipa, args.loader, args.output_ipa)
    elif args.command == "coexist":
        make_coexist_ipa(
            args.input_ipa,
            args.output_ipa,
            bundle_id=args.bundle_id,
            display_name=args.display_name,
            scheme_prefix=args.scheme_prefix,
            strip_extensions=not args.keep_extensions,
        )
        if args.report:
            _write_json(inspect_coexist(args.output_ipa), args.report)
    elif args.command == "icon":
        _write_json(
            replace_app_icon(
                args.input_ipa,
                args.master_png,
                args.icon_document,
                args.output_ipa,
            ),
            args.report,
        )
    elif args.command == "account-safety":
        result = assess_account_safety(
            args.baseline_ipa,
            args.candidate_ipa,
        )
        _write_json(result, args.output)
        return 1 if result["release_blocked"] else 0
    elif args.command == "verify":
        result = verify_package(args.ipa)
        _write_json(result, args.output)
        return 0 if result["valid"] else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
