# WeChat IPA Audit

微信 iOS 8.0.75 样本清点、静态审计、唯一组件差分和模块化加载器工程。

## 已实现

- 逐包记录 SHA-256、Bundle、版本/build、签名配置、Entitlements、URL Scheme。
- 解析所有 Mach-O load commands、加密信息与代码签名命令。
- 相对纯净砸壳基线只提取新增可执行组件，检查域名、动态加载、反调试和敏感 API。
- YARA 与 ClamAV 本地扫描；样本及闭源第三方 dylib 不提交到仓库。
- 17 个 `ModuleDescriptor` 全部默认关闭；连续两次异常启动进入 Safe Mode。
- 登录、凭据、Keychain、支付和核心会话类在 Hook 拒绝清单中。
- macOS GitHub Actions 构建 arm64 iOS `WeChatMods.dylib`。
- LIEF 向预签名 IPA 写入加载命令；最终由 iLoader 重签和安装。

## 本地验证

```powershell
$env:PYTHONPATH = "src"
py -3 -m unittest discover -s tests -v
py -3 -m wechat_ipa_audit.cli audit SAMPLE.ipa --output reports\SAMPLE.json
py -3 -m wechat_ipa_audit.cli diff reports\BASE.json reports\SAMPLE.json --output reports\DIFF.json
py -3 -m wechat_ipa_audit.cli package BASE.ipa staged.ipa --modules data\modules.json
py -3 -m wechat_ipa_audit.cli inject staged.ipa dist\WeChatMods.dylib wechatmods-iloader.ipa
py -3 -m wechat_ipa_audit.cli verify wechatmods-iloader.ipa

# 等价的一键构建：写入全关闭清单、注入加载器并验证
.\scripts\build-iloader.ps1 -BaseIpa BASE.ipa -OutputIpa wechatmods-iloader.ipa
```

## 构建边界

`wechatmods-iloader.ipa` 是签名前产物。修改 Mach-O 后原签名不再有效，安装前必须由
iLoader v2.2.7 用设备实际可用证书重签。`guanti/qy/wx/mm` 仅应在证书实际具备相应
Bundle ID、App Groups、Keychain Groups 与推送能力时生成。

静态规则命中表示需要复核，不等同于恶意软件结论。动态登录、推送、CallKit、
iPad 登录、7 天刷新和资源回归必须在隔离设备与测试号上补齐。

## 数据隔离

`.gitignore` 排除 `samples/`、`components/`、`reports/`、`tools/`、`dist/` 和
所有 IPA。仓库仅保存分析器、规则、模块源码、测试和可复现构建工作流。
