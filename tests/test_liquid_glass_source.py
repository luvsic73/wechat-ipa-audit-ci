import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LiquidGlassSourceTests(unittest.TestCase):
    def test_liquid_glass_is_a_fixed_shell_not_a_module(self) -> None:
        modules = json.loads(
            (ROOT / "data" / "modules.json").read_text(encoding="utf-8")
        )["modules"]
        module_ids = {module["id"] for module in modules}
        bootstrap = (
            ROOT / "ios" / "WeChatMods" / "WeChatModsBootstrap.m"
        ).read_text(encoding="utf-8")

        self.assertNotIn("theme", module_ids)
        self.assertIn("[WMLiquidGlassStyle install]", bootstrap)

    def test_build_includes_runtime_native_glass_implementation(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMLiquidGlassStyle.m"
        ).read_text(encoding="utf-8")
        build_script = (ROOT / "scripts" / "build-loader.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('NSClassFromString(@"UIGlassEffect")', source)
        self.assertIn("[effectClass new]", source)
        self.assertIn('NSSelectorFromString(@"setInteractive:")', source)
        self.assertNotIn('NSSelectorFromString(@"initWithStyle:")', source)
        self.assertIn("UIBlurEffectStyleSystemMaterial", source)
        self.assertIn("UIVisualEffectView", source)
        self.assertNotIn("UINavigationBarAppearance", source)
        self.assertNotIn("UITabBarAppearance", source)
        self.assertNotIn("UIToolbarAppearance", source)
        self.assertNotIn("UINavigationBar.appearance", source)
        self.assertNotIn("WMGlassifyViewTree", source)
        self.assertNotIn("WMUsesNativeTabGlass", source)
        self.assertIn("wechatmods.floating-tab-glass", source)
        self.assertIn("UITabBar", source)
        self.assertIn("shadowImage", source)
        self.assertIn("backgroundImage", source)
        self.assertIn("WMLiquidGlassStyle.m", build_script)

    def test_glass_respects_accessibility_and_refreshes_visible_scenes(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMLiquidGlassStyle.m"
        ).read_text(encoding="utf-8")

        self.assertIn("UIAccessibilityIsReduceTransparencyEnabled()", source)
        self.assertIn("UIAccessibilityDarkerSystemColorsEnabled()", source)
        self.assertIn(
            "UIAccessibilityReduceTransparencyStatusDidChangeNotification",
            source,
        )
        self.assertIn(
            "UIAccessibilityDarkerSystemColorsStatusDidChangeNotification",
            source,
        )
        self.assertIn("UIApplication.sharedApplication.connectedScenes", source)
        self.assertIn("UISceneActivationStateForegroundActive", source)
        self.assertIn("UIWindowScene", source)
        self.assertNotIn("UIApplication.sharedApplication.windows", source)

    def test_bar_layout_hooks_are_idempotent(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMLiquidGlassStyle.m"
        ).read_text(encoding="utf-8")

        self.assertIn("WMPreparedNavigationBarKey", source)
        self.assertIn("WMPreparedTabBarKey", source)
        self.assertIn(
            "fabs(bottom.constant + safeBottom) > 0.5",
            source,
        )
        self.assertIn(
            "fabs(backdrop.layer.cornerRadius - cornerRadius) > 0.5",
            source,
        )


if __name__ == "__main__":
    unittest.main()
