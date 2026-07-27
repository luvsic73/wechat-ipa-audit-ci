# 微信 8.0.75 共存构建交付

目标设备：iPhone / iOS 26.2。

## 推荐安装包

`wechatmods-coexist-iloader-v2.ipa`

- Bundle ID：`com.luvsic73.wechatmods`
- 显示名称：`微信 Glass`
- SHA-256：`00131ff449ab8d7826685b84e17473686da62b1dfc86bdc12698707d895b1879`
- 状态：签名前 IPA，交给 iLoader 使用设备证书重签
- 与官方标识的静态冲突：Bundle ID 0、URL Scheme 0、扩展签名残留 0

`wechatmods-replacement-official-id.ipa` 是同官方 Bundle ID 的替换型留档，不用于共存安装。

## 当前真实功能

| 功能 | 默认 | 构建证据 | 实机状态 |
|---|---|---|---|
| iOS 26 原生 Liquid Glass | 固定开启 | 动态系统栏 + 窗口上下安全区；`UIGlassEffect`，arm64 编译通过 | 待签名验证 |
| 与官方客户端共存 / 基础多开 | 固定配置 | 独立 Bundle ID、URL Scheme、数据容器 | 待双 App 同机验证 |
| 防撤回 | 默认开启 | 8.0.75 中存在 `CMessageMgr.onRevokeMsg:`；运行前校验签名 | 待单聊、群聊验证 |
| 设置入口 | 固定开启 | “我 → 设置 → 微信 Glass”，原生 inset-grouped 功能页 | 待点击验证 |
| Safe Mode | 固定开启 | 连续两次异常启动跳过功能模块 | 待故障注入验证 |
| 模块健康记录 | 固定开启 | 写入 `wechatmods.module-health` | 待读取验证 |

登录、文本、图片、语音、视频、文件、群聊和扫码沿用 8.0.75 主程序。当前加载器未 Hook
登录、认证、凭据、Keychain、支付或核心 Session 类。签名后的设备结果是这些流程的最终验收依据。

其余 15 个条目目前只有描述符，默认关闭且 Hook 列表为空。完整状态见
`reports/功能清单与真实状态.md` 与 `reports/feature-status.json`。

## 共存基础包的取舍

为减少个人签名所需 App ID 数量和扩展冲突，本包移除了 Notification Service、系统分享、
Siri、Widget、录屏和 Watch 扩展。因此首轮重点是主 App 的登录、多开、消息、防撤回和稳定性；
上述系统扩展待取得设备实际签名能力后分别适配。

## iLoader 安装顺序

1. 在 iLoader v2.2.7 导入 `wechatmods-coexist-iloader-v2.ipa`。
2. 选择设备证书完成重签和安装；保留 iLoader 的签名日志。
3. 首次安装后记录实际 Bundle ID、Entitlements、App Groups、Keychain Groups。
4. 确认官方微信和“微信 Glass”同时存在，再使用隔离测试号登录。
5. 按 `reports/动态测试与验收清单.md` 完成收发消息、防撤回、冷启动和后台恢复。

## 关键校验

- GitHub Actions：run `30291317036`，test/build 均成功，Objective-C 编译警告 0。
- `WeChatMods.dylib` SHA-256：
  `712c8bacc90ba2a5eb4df827fb366ec86b68af723b4c70076b11d48d636e5907`
- 共存 IPA ClamAV 1.5.3：0 infected，扫描解包数据 1.90 GiB。
- 包清单：16 个描述符，仅 `anti-revoke` 为 `enabled=true`。

所有交付文件的哈希见 `SHA256SUMS.txt`。
