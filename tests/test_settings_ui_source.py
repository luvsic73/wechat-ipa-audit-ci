import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class SettingsUISourceTests(unittest.TestCase):
    def test_settings_entry_uses_wechat_native_settings_table(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMSettingsEntry.m"
        ).read_text(encoding="utf-8")

        self.assertIn('NSClassFromString(@"NewSettingViewController")', source)
        self.assertIn('class_getInstanceVariable(settingsClass, "m_tableViewMgr")', source)
        self.assertIn('NSClassFromString(@"WCTableViewSectionManager")', source)
        self.assertIn('NSClassFromString(@"WCTableViewNormalCellManager")', source)
        self.assertIn('NSSelectorFromString(@"insertSection:At:")', source)
        self.assertIn(
            '@"normalCellForSel:target:title:accessoryType:"',
            source,
        )
        self.assertNotIn("floating", source.lower())

    def test_settings_controller_exposes_real_feature_state(self) -> None:
        controller = (
            ROOT / "ios" / "WeChatMods" / "WMSettingsViewController.m"
        ).read_text(encoding="utf-8")
        store = (
            ROOT / "ios" / "WeChatMods" / "WMFeatureStore.m"
        ).read_text(encoding="utf-8")
        bootstrap = (
            ROOT / "ios" / "WeChatMods" / "WeChatModsBootstrap.m"
        ).read_text(encoding="utf-8")

        self.assertIn("UITableViewStyleInsetGrouped", controller)
        self.assertIn('@"防撤回"', controller)
        self.assertIn("UISwitch", controller)
        self.assertIn('@"更改后重启微信生效"', controller)
        self.assertIn('@"wechatmods.module-overrides"', store)
        self.assertIn(
            "isModuleEnabled:descriptor.moduleID",
            bootstrap,
        )

    def test_glass_shell_covers_dynamic_bars_and_safe_areas(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMLiquidGlassStyle.m"
        ).read_text(encoding="utf-8")

        self.assertIn("UIWindowDidBecomeVisibleNotification", source)
        self.assertIn("safeAreaLayoutGuide.topAnchor", source)
        self.assertIn("safeAreaLayoutGuide.bottomAnchor", source)
        self.assertIn('NSSelectorFromString(@"didMoveToWindow")', source)
        self.assertIn("WMInstallWindowGlassChrome", source)

    def test_loader_build_includes_settings_sources(self) -> None:
        build_script = (ROOT / "scripts" / "build-loader.sh").read_text(
            encoding="utf-8"
        )

        for source in (
            "WMFeatureStore.m",
            "WMSettingsEntry.m",
            "WMSettingsViewController.m",
        ):
            self.assertIn(source, build_script)


if __name__ == "__main__":
    unittest.main()
