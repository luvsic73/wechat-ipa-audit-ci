# WeChatMods loader

The loader reads `WeChatMods/module-manifest.json`, validates version and the
hook denylist, and keeps every module disabled in the initial distribution.
Two consecutive launches that do not reach the 30-second stable mark enable
Safe Mode and record the last enabled module IDs.

The denylist covers login, authentication, credential, Keychain, payment, and
core session hook names. Push, CallKit, iPad session, and multi-instance work
remain separate adapters guarded by signing-capability health checks.
