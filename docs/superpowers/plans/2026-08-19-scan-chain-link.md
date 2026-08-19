# 扫码/导入与首页选中链联动校验 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让扫码签名和文件导入两个入口都按首页下拉选中的链做前置校验，链不匹配时直接阻止跳转并提示。

**Architecture:** 在 `ChainRegistry` 加两个纯静态方法（`resolveChainId` + `mismatchMessage`），承载链解析与不匹配提示文案生成，便于纯单元测试。`ScanTxScreen` 增加构造参数 `requiredChainId`，HomeScreen 跳转从命名路由改为 `Navigator.push` 传参；`_parseAndNavigate` 直接读 `_selectedChainId`。两个入口在 `jsonDecode` 后、跳转前调用 `ChainRegistry.mismatchMessage` 校验，不匹配弹 SnackBar 阻止。

**Tech Stack:** Flutter 3.11 / Dart 3.11、mobile_scanner、flutter_secure_storage、flutter_test

---

## File Structure

| 文件 | 职责 | 操作 |
|------|------|------|
| `lib/services/chain_registry.dart` | 链注册中心；新增链解析与不匹配文案 | Modify |
| `lib/screens/scan_tx_screen.dart` | 扫码页；加 `requiredChainId` 参数 + `_onDetect` 校验 | Modify |
| `lib/screens/home_screen.dart` | 首页；扫码改 push 传参 + `_parseAndNavigate` 校验 + 空链禁用 | Modify |
| `lib/main.dart` | 移除 `/scan-tx` 命名路由（改用直接 push） | Modify |
| `lib/screens/README.md` | 扫码页职责描述更新 | Modify |
| `lib/services/README.md` | ChainRegistry 新增方法文档 | Modify |
| `test/services/chain_registry_test.dart` | resolveChainId / mismatchMessage 单元测试 | Create |

---

## Task 1: ChainRegistry 新增 resolveChainId + mismatchMessage（TDD）

**Files:**
- Create: `coldwallet-app/test/services/chain_registry_test.dart`
- Modify: `coldwallet-app/lib/services/chain_registry.dart`

- [ ] **Step 1: 写失败测试**

Create `coldwallet-app/test/services/chain_registry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/chain_registry.dart';

void main() {
  group('ChainRegistry.resolveChainId', () {
    test('returns cardano-preview when chainId field absent', () {
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });

    test('returns the chainId value when present', () {
      final json = <String, dynamic>{'chainId': 'evm-97'};
      expect(ChainRegistry.resolveChainId(json), 'evm-97');
    });

    test('returns cardano-preview when chainId is explicitly null', () {
      final json = <String, dynamic>{'chainId': null};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });

    test('does not crash on non-String chainId (defensive)', () {
      final json = <String, dynamic>{'chainId': 123};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });
  });

  group('ChainRegistry.mismatchMessage', () {
    test('returns null when chains match', () {
      expect(
        ChainRegistry.mismatchMessage('cardano-preview', 'cardano-preview'),
        isNull,
      );
    });

    test('returns message with friendly names on mismatch', () {
      final msg = ChainRegistry.mismatchMessage('evm-11155111', 'evm-97');
      expect(msg, isNotNull);
      expect(msg!, contains('Ethereum Sepolia'));
      expect(msg, contains('BSC Testnet'));
      expect(msg, contains('请切换链后重试'));
    });

    test('falls back to raw chainId when config not found', () {
      final msg = ChainRegistry.mismatchMessage('evm-11155111', 'unknown-chain');
      expect(msg, isNotNull);
      expect(msg!, contains('unknown-chain'));
    });

    test('cardano scanned (no chainId) matches selected cardano-preview', () {
      // 模拟扫码得到无 chainId 的 Cardano ColdExport
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      final scanned = ChainRegistry.resolveChainId(json);
      expect(ChainRegistry.mismatchMessage('cardano-preview', scanned), isNull);
    });

    test('cardano scanned does NOT match selected evm chain', () {
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      final scanned = ChainRegistry.resolveChainId(json);
      final msg = ChainRegistry.mismatchMessage('evm-11155111', scanned);
      expect(msg, isNotNull);
      expect(msg!, contains('Ethereum Sepolia'));
      expect(msg, contains('Cardano Preview'));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `coldwallet-app/` 下）:
```
flutter test test/services/chain_registry_test.dart
```
Expected: FAIL，`ChainRegistry.resolveChainId` 方法未定义 / `mismatchMessage` 未定义。

- [ ] **Step 3: 实现两个静态方法**

在 `coldwallet-app/lib/services/chain_registry.dart` 的 `ChainRegistry` 类内（`getConfig` 方法之后）追加：

```dart
  /// 从交易 JSON 解析链 ID。
  ///
  /// 无 `chainId` 字段或值为非 String 时视为 Cardano（`cardano-preview`），
  /// 向后兼容不含 chainId 字段的 ColdExport。
  static String resolveChainId(Map<String, dynamic> json) {
    final v = json['chainId'];
    if (v is String) return v;
    return 'cardano-preview';
  }

  /// 生成"链不匹配"提示文案，匹配时返回 null。
  ///
  /// [selectedChainId] 当前选中的链 ID；
  /// [scannedChainId] 扫码/导入交易解析出的链 ID。
  /// 链名取不到时回退显示原始 chainId。
  static String? mismatchMessage(
    String selectedChainId,
    String scannedChainId,
  ) {
    if (scannedChainId == selectedChainId) return null;
    final selected = getConfig(selectedChainId)?.name ?? selectedChainId;
    final scanned = getConfig(scannedChainId)?.name ?? scannedChainId;
    return '当前选中 $selected，扫到的交易属于 $scanned，请切换链后重试';
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run:
```
flutter test test/services/chain_registry_test.dart
```
Expected: PASS（全部 9 个 test）。

- [ ] **Step 5: 静态分析**

Run:
```
flutter analyze lib/services/chain_registry.dart
```
Expected: No issues found.

- [ ] **Step 6: Commit**

```
git add coldwallet-app/lib/services/chain_registry.dart coldwallet-app/test/services/chain_registry_test.dart
git commit -m "feat: add ChainRegistry.resolveChainId and mismatchMessage for chain link validation"
```

---

## Task 2: ScanTxScreen 加 requiredChainId 参数 + _onDetect 校验

**Files:**
- Modify: `coldwallet-app/lib/screens/scan_tx_screen.dart`

> 说明：`ScanTxScreen` 内嵌 `MobileScanner` 原生插件，无法在 `flutter test` 环境 pump，
> 核心校验逻辑已在 Task 1 单元测试覆盖，本任务以 `flutter analyze` + 编译保证正确性。

- [ ] **Step 1: 改 ScanTxScreen 构造与 _onDetect**

将 `coldwallet-app/lib/screens/scan_tx_screen.dart` 整体替换为：

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/chain_registry.dart';
import 'tx_detail_screen.dart';

/// 扫描交易二维码页面
///
/// 使用摄像头扫描联网设备展示的未签名交易二维码，
/// 验证为 JSON 后按 [requiredChainId] 校验链匹配，匹配则跳转到交易详情页；
/// 不匹配则提示并允许重新扫码。
class ScanTxScreen extends StatefulWidget {
  /// 当前首页选中的链 ID，扫码交易必须与之匹配才放行。
  final String requiredChainId;

  const ScanTxScreen({super.key, required this.requiredChainId});

  @override
  State<ScanTxScreen> createState() => _ScanTxScreenState();
}

class _ScanTxScreenState extends State<ScanTxScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _scanned = true);

    try {
      final json = jsonDecode(rawValue) as Map<String, dynamic>;

      // 链联动校验：扫到的交易链必须与当前选中链一致
      final scannedChainId = ChainRegistry.resolveChainId(json);
      final mismatch = ChainRegistry.mismatchMessage(
        widget.requiredChainId,
        scannedChainId,
      );
      if (mismatch != null) {
        setState(() => _scanned = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mismatch)),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: rawValue),
        ),
      );
    } catch (e) {
      setState(() => _scanned = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法解析二维码: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描交易二维码')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            top: 100,
            left: 40,
            right: 40,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '将二维码对准框内',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

变更要点：
1. 新增 `import '../services/chain_registry.dart';`
2. `ScanTxScreen` 加 `final String requiredChainId;` + 构造参数 `required this.requiredChainId`
3. `_onDetect` 把 `jsonDecode` 结果存为 `json`，调用 `ChainRegistry.resolveChainId` + `mismatchMessage`，不匹配则复位 `_scanned` + SnackBar + return

- [ ] **Step 2: 静态分析**

Run:
```
flutter analyze lib/screens/scan_tx_screen.dart
```
Expected: No issues found.

- [ ] **Step 3: Commit**

```
git add coldwallet-app/lib/screens/scan_tx_screen.dart
git commit -m "feat: ScanTxScreen validates scanned tx chain against requiredChainId"
```

---

## Task 3: HomeScreen 扫码改 push 传参 + _parseAndNavigate 校验

**Files:**
- Modify: `coldwallet-app/lib/screens/home_screen.dart`

- [ ] **Step 1: 补 import**

确认 `home_screen.dart` 顶部已 import `scan_tx_screen.dart`（第 11 行已有 `import 'tx_detail_screen.dart';`，需新增 ScanTxScreen import）。

在 `import 'tx_detail_screen.dart';` 之前加一行：

```dart
import 'scan_tx_screen.dart';
import 'tx_detail_screen.dart';
```

并在 import 区确认已有 `import '../services/chain_registry.dart';`（第 8 行已有）。

- [ ] **Step 2: 改扫码按钮 onPressed**

将 `build()` 中扫码按钮（约第 166-176 行）：

```dart
                  _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: '扫码签名',
                    description: '扫描联网设备上的未签名交易二维码',
                    onPressed: _hasWallets
                        ? () async {
                            await Navigator.pushNamed(context, '/scan-tx');
                            if (mounted) _loadState();
                          }
                        : null,
                  ),
```

替换为（`_selectedChainId == null` 时禁用，并改用 `Navigator.push` 传参）：

```dart
                  _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: '扫码签名',
                    description: '扫描联网设备上的未签名交易二维码',
                    onPressed: _hasWallets && _selectedChainId != null
                        ? () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanTxScreen(
                                  requiredChainId: _selectedChainId!,
                                ),
                              ),
                            );
                            if (mounted) _loadState();
                          }
                        : null,
                  ),
```

- [ ] **Step 3: 改 _parseAndNavigate 加链校验**

将 `_parseAndNavigate`（约第 271-292 行）：

```dart
  void _parseAndNavigate(String jsonStr) {
    if (jsonStr.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据不能为空')));
      return;
    }
    try {
      // Validate JSON, then pass raw string
      jsonDecode(jsonStr);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: jsonStr),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
```

替换为：

```dart
  void _parseAndNavigate(String jsonStr) {
    if (jsonStr.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据不能为空')));
      return;
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 链联动校验：导入的交易链必须与当前选中链一致
      if (_selectedChainId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前无可用链，请先创建钱包')),
        );
        return;
      }
      final scannedChainId = ChainRegistry.resolveChainId(json);
      final mismatch = ChainRegistry.mismatchMessage(
        _selectedChainId!,
        scannedChainId,
      );
      if (mismatch != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mismatch)),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TxDetailScreen(rawJson: jsonStr),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
```

- [ ] **Step 4: 静态分析**

Run:
```
flutter analyze lib/screens/home_screen.dart
```
Expected: No issues found.

- [ ] **Step 5: Commit**

```
git add coldwallet-app/lib/screens/home_screen.dart
git commit -m "feat: HomeScreen links scan/import to selected chain with mismatch guard"
```

---

## Task 4: main.dart 移除 /scan-tx 命名路由

**Files:**
- Modify: `coldwallet-app/lib/main.dart`

- [ ] **Step 1: 移除命名路由与无用 import**

`main.dart` 第 10 行 `import 'screens/scan_tx_screen.dart';` 与第 47 行 `'/scan-tx': (context) => const ScanTxScreen(),` 已无人引用（HomeScreen 改用直接 push）。

将第 44-48 行：

```dart
      routes: {
        '/': (context) => const HomeScreen(),
        '/wallet-setup': (context) => const WalletSetupScreen(),
        '/scan-tx': (context) => const ScanTxScreen(),
      },
```

替换为：

```dart
      routes: {
        '/': (context) => const HomeScreen(),
        '/wallet-setup': (context) => const WalletSetupScreen(),
      },
```

并删除第 10 行 `import 'screens/scan_tx_screen.dart';`。

- [ ] **Step 2: 静态分析**

Run:
```
flutter analyze lib/main.dart
```
Expected: No issues found.

- [ ] **Step 3: 全量测试**

Run（在 `coldwallet-app/` 下）:
```
flutter test
```
Expected: 全部 PASS（含 Task 1 新增的 chain_registry_test.dart）。

- [ ] **Step 4: Commit**

```
git add coldwallet-app/lib/main.dart
git commit -m "refactor: remove unused /scan-tx named route now that HomeScreen pushes directly"
```

---

## Task 5: 文档更新

**Files:**
- Modify: `coldwallet-app/lib/screens/README.md`
- Modify: `coldwallet-app/lib/services/README.md`

- [ ] **Step 1: 更新 screens/README.md 的 ScanTxScreen 行**

将 `lib/screens/README.md` 中 ScanTxScreen 一行：

```
| scan_tx_screen.dart | ScanTxScreen | 扫描交易二维码，扫描未签名交易 JSON 并跳转到详情页 |
```

替换为：

```
| scan_tx_screen.dart | ScanTxScreen | 扫描交易二维码，校验交易链与首页选中链一致后跳转详情页，不匹配则提示并阻止跳转 |
```

- [ ] **Step 2: 更新 services/README.md 的 ChainRegistry 方法表**

在 `lib/services/README.md` 的 ChainRegistry 文件清单或方法表中，补充两个新方法。若 README 以方法表格形式列出 ChainRegistry，追加行：

```
| `resolveChainId(json)` | `String` | 从交易 JSON 解析链 ID，无 chainId 字段视为 Cardano |
| `mismatchMessage(selectedChainId, scannedChainId)` | `String?` | 链不匹配提示文案，匹配返回 null |
```

若 README 无方法表格，在 ChainRegistry 职责描述处补一句：

> 提供交易链解析（`resolveChainId`）与不匹配提示文案（`mismatchMessage`），供扫码/导入入口做链联动校验。

- [ ] **Step 3: Commit**

```
git add coldwallet-app/lib/screens/README.md coldwallet-app/lib/services/README.md
git commit -m "docs: document scan/import chain-link validation"
```

---

## Self-Review

**1. Spec coverage:**
- 校验规则 resolveChainId（无 chainId→cardano-preview）→ Task 1 ✓
- ScanTxScreen 加 requiredChainId + _onDetect 校验 → Task 2 ✓
- HomeScreen 扫码改 push 传参 → Task 3 Step 2 ✓
- HomeScreen 文件导入 _parseAndNavigate 校验 → Task 3 Step 3 ✓
- _selectedChainId == null 禁用扫码 → Task 3 Step 2（`_hasWallets && _selectedChainId != null`）✓
- main.dart 移除 /scan-tx → Task 4 ✓
- 提示文案设计（友好名称 + 回退 chainId）→ Task 1 mismatchMessage ✓
- 测试计划（resolveChainId 单元测试）→ Task 1 ✓
- 文档维护 → Task 5 ✓

**2. Placeholder scan:** 无 TBD/TODO，所有代码步骤含完整代码块。✓

**3. Type consistency:**
- `resolveChainId(Map<String, dynamic>) → String`：Task 1 定义，Task 2/3 调用签名一致 ✓
- `mismatchMessage(String, String) → String?`：Task 1 定义，Task 2/3 调用一致 ✓
- `ScanTxScreen({required this.requiredChainId})`：Task 2 定义，Task 3 构造 `ScanTxScreen(requiredChainId: _selectedChainId!)` 一致 ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-19-scan-chain-link.md`. Two execution options:

1. **Subagent-Driven (recommended)** — 我每个 Task 派一个新 subagent 执行，Task 之间我做 review，迭代快。
2. **Inline Execution** — 在当前会话用 executing-plans 批量执行，带检查点。

哪种方式？（注：按项目规则，commit 步骤需你明确授权后我才执行 git commit。）
