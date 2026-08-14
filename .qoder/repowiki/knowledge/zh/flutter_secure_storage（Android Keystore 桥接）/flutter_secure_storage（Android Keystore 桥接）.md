---
kind: external_dependency
name: flutter_secure_storage（Android Keystore 桥接）
slug: flutter-secure-storage
category: external_dependency
category_hints:
    - framework_behavior
    - auth_protocol
scope:
    - '**'
---

用于在 Android 设备上安全存储敏感数据，底层对接 Android Keystore。
- 冷钱包 App：存储助记词、PIN 哈希、多钱包列表及当前选中钱包 ID。
- watch 端：仅存储 Blockfrost API Key（地址/名称走 SharedPreferences 明文）。
- 版本差异：v11 起移除了 encryptedSharedPreferences 等构造参数，改为默认构造即可；v9→v11 行为有破坏性变更。
- 安全边界：仅用于凭证类数据，私钥/助记词从不落地为明文文件。