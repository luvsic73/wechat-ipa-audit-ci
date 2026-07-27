#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
OUTPUT="${1:-$ROOT/dist/WeChatMods.dylib}"
mkdir -p "$(dirname "$OUTPUT")"

xcrun --sdk iphoneos clang \
  -fobjc-arc \
  -fmodules \
  -isysroot "$SDK" \
  -arch arm64 \
  -miphoneos-version-min=15.0 \
  -dynamiclib \
  "$ROOT/ios/WeChatMods/WMAntiRevokeModule.m" \
  "$ROOT/ios/WeChatMods/WMFeatureStore.m" \
  "$ROOT/ios/WeChatMods/WMLiquidGlassStyle.m" \
  "$ROOT/ios/WeChatMods/WMLoginLayoutAdapter.m" \
  "$ROOT/ios/WeChatMods/WMModuleDescriptor.m" \
  "$ROOT/ios/WeChatMods/WMModuleRuntime.m" \
  "$ROOT/ios/WeChatMods/WMSafeModeController.m" \
  "$ROOT/ios/WeChatMods/WMSettingsEntry.m" \
  "$ROOT/ios/WeChatMods/WMSettingsViewController.m" \
  "$ROOT/ios/WeChatMods/WeChatModsBootstrap.m" \
  -framework Foundation \
  -framework UIKit \
  -install_name "@executable_path/Frameworks/WeChatMods.dylib" \
  -Wl,-dead_strip \
  -o "$OUTPUT"

codesign --force --sign - "$OUTPUT"
file "$OUTPUT"
codesign --display --verbose=2 "$OUTPUT"
