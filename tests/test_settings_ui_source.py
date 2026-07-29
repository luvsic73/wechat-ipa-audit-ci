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

    def test_settings_entry_retries_and_hooks_both_lifecycle_seams(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMSettingsEntry.m"
        ).read_text(encoding="utf-8")

        self.assertIn("UIApplicationDidFinishLaunchingNotification", source)
        self.assertIn("UIApplicationDidBecomeActiveNotification", source)
        self.assertIn('NSSelectorFromString(@"viewDidLoad")', source)
        self.assertIn('NSSelectorFromString(@"reloadTableData")', source)
        self.assertIn("WMSettingsEntryMarkerKey", source)
        self.assertIn("objc_setAssociatedObject", source)

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
        self.assertIn("prepareForSchemaVersion", bootstrap)
        self.assertIn("WMFeatureStore.enabledModuleIDs", bootstrap)
        self.assertNotIn("defaultValue:descriptor.isEnabled", bootstrap)

    def test_glass_shell_covers_dynamic_navigation_and_control_bars(self) -> None:
        source = (
            ROOT / "ios" / "WeChatMods" / "WMLiquidGlassStyle.m"
        ).read_text(encoding="utf-8")

        self.assertIn("UIWindowDidBecomeVisibleNotification", source)
        self.assertIn('NSSelectorFromString(@"didMoveToWindow")', source)
        self.assertIn('NSSelectorFromString(@"layoutSubviews")', source)
        self.assertIn("WMRefreshVisibleLayouts", source)
        self.assertIn('NSClassFromString(@"MMUINavigationBar")', source)
        self.assertIn('NSClassFromString(@"MMTabBar")', source)
        self.assertIn("WMCustomNavigationHookInstalled", source)
        self.assertIn("WMInstallDynamicBarHooks();", source)
        self.assertNotIn("WMGlassifyWindows", source)
        self.assertNotIn("UINavigationBar.appearance", source)
        self.assertNotIn("WMInstallWindowGlassChrome", source)
        self.assertNotIn("WMInstallWindowEdgeGlass", source)

    def test_official_login_layout_is_left_unhooked(
        self,
    ) -> None:
        build_script = (ROOT / "scripts" / "build-loader.sh").read_text(
            encoding="utf-8"
        )
        simulator_script = (
            ROOT / "scripts" / "run-ios-simulator-ui-tests.sh"
        ).read_text(encoding="utf-8")
        bootstrap = (
            ROOT / "ios" / "WeChatMods" / "WeChatModsBootstrap.m"
        ).read_text(encoding="utf-8")
        self.assertNotIn("WMLoginLayoutAdapter", build_script)
        self.assertNotIn("WMLoginLayoutAdapter", simulator_script)
        self.assertNotIn("WMLoginLayoutAdapter", bootstrap)

    def test_settings_are_dynamic_type_accessible_and_localized(self) -> None:
        controller = (
            ROOT / "ios" / "WeChatMods" / "WMSettingsViewController.m"
        ).read_text(encoding="utf-8")
        entry = (
            ROOT / "ios" / "WeChatMods" / "WMSettingsEntry.m"
        ).read_text(encoding="utf-8")
        localization = (
            ROOT / "ios" / "WeChatMods" / "WMLocalization.m"
        ).read_text(encoding="utf-8")
        build_script = (ROOT / "scripts" / "build-loader.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("WMLocalizedString", controller)
        self.assertIn("WMLocalizedString", entry)
        self.assertIn('URLForResource:@"WeChatModsLocalization"', localization)
        self.assertIn('withExtension:@"bundle"', localization)
        self.assertIn("preferredFontForTextStyle", controller)
        self.assertIn("detailTextLabel.numberOfLines = 0", controller)
        self.assertIn("toggle.accessibilityHint", controller)
        self.assertIn("objc_setAssociatedObject", controller)
        self.assertIn("UIAccessibilityPostNotification", controller)
        self.assertNotIn(
            "descriptorForModuleID:toggle.accessibilityIdentifier",
            controller,
        )
        self.assertIn("WMLocalization.m", build_script)
        for language in ("zh-Hans", "en"):
            strings = (
                ROOT
                / "ios"
                / "WeChatMods"
                / "Resources"
                / "WeChatModsLocalization.bundle"
                / f"{language}.lproj"
                / "Localizable.strings"
            )
            self.assertTrue(strings.is_file())

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

    def test_ios_26_simulator_host_emits_runtime_diagnostics(self) -> None:
        host = (
            ROOT / "ios" / "SimulatorHost" / "SimulatorHost.m"
        ).read_text(encoding="utf-8")
        script = (
            ROOT / "scripts" / "run-ios-simulator-ui-tests.sh"
        ).read_text(encoding="utf-8")
        workflow = (
            ROOT / ".github" / "workflows" / "build-loader.yml"
        ).read_text(encoding="utf-8")

        for key in (
            "loader_constructor_ran",
            "settings_entry_count",
            "settings_controller_opened",
            "settings_snapshot_written",
            "settings_switch_count",
            "settings_switches_with_hints",
            "settings_multiline_details",
            "glass_effect_count",
            "glass_backdrop_count",
            "glass_effect_api_available",
            "glass_effect_default_initializer_available",
            "glass_effect_class_names",
            "window_matches_screen",
            "login_title_visible",
            "login_action_visible",
            "floating_tab_glass_present",
            "floating_tab_glass_detached",
            "glass_test_content_count",
        ):
            self.assertIn(key, host)
        self.assertIn("@interface MMUINavigationBar : UIView", host)
        self.assertIn("@interface MMTabBar : UITabBar", host)
        self.assertIn('setTitle:@"登录"', host)
        self.assertIn('@"wechatmods.login-action"', host)
        self.assertLess(
            host.index("tabs.selectedIndex = 1;"),
            host.index("WMCountGlassEffects(window)"),
        )
        self.assertIn("iPhone 17 Pro Max", script)
        self.assertIn("TARGET_RUNTIME_VERSION", script)
        self.assertIn("module-manifest.json", script)
        self.assertIn("data/modules.json", script)
        self.assertIn("simctl", script)
        self.assertIn("SimulatorHostDiagnostics.json", script)
        self.assertIn("SimulatorHostSettings.png", script)
        self.assertIn("[view.layer renderInContext:context.CGContext]", host)
        self.assertNotIn("drawViewHierarchyInRect", host)
        self.assertIn("SimulatorHostPhase.txt", host)
        self.assertIn("SimulatorHostPhase.txt", script)
        self.assertIn("seq 1 120", script)
        self.assertIn("SimulatorHost-launch.log", script)
        self.assertIn('data.get("glass_effect_count", 0) < 2', script)
        self.assertIn('data.get("glass_backdrop_count", 0) < 2', script)
        self.assertIn('"login_title_visible": True', script)
        self.assertIn('"login_action_visible": True', script)
        self.assertIn('"floating_tab_glass_present": True', script)
        self.assertIn('"floating_tab_glass_detached": True', script)
        self.assertIn('data.get("glass_test_content_count", 0) < 3', script)
        self.assertIn("simulator-ui", workflow)


if __name__ == "__main__":
    unittest.main()
