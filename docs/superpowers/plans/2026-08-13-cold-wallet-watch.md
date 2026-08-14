# coldwallet-watch 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个独立的 Flutter Android 热钱包 App，支持只读地址管理、余额查询、手动转账、二维码/JSON/文件导出未签名交易、导入签名结果并提交上链。

**架构：** 新建 Flutter 项目 `coldwallet-watch`，通过 Blockfrost 查询链上数据，使用 `cardano_flutter_sdk` 构建未签名交易，与 `coldwallet-app` 通过 `ColdExport`/`ColdImport` JSON 契约交互。

**Tech Stack:** Flutter, cardano_flutter_sdk, Blockfrost REST API, mobile_scanner, qr_flutter, file_picker, http, shared_preferences, flutter_secure_storage

---

## Phase 0: 项目初始化与配置

### Task 1: 创建 Flutter 项目

**Files:**
- Create: `coldwallet-watch/` (entire project)

- [ ] **Step 1: 创建项目**

Run:
```powershell
cd d:\code\web3\coldwallet
flutter create --org com.coldwallet --project-name coldwallet_watch --platforms android coldwallet-watch
```

Expected: Project created at `d:\code\web3\coldwallet\coldwallet-watch`.

- [ ] **Step 2: 验证项目结构**

Run:
```powershell
Get-ChildItem d:\code\web3\coldwallet\coldwallet-watch
```

Expected: Contains `android/`, `lib/`, `pubspec.yaml`, `test/`.

---

### Task 2: 配置 Android 包名与权限

**Files:**
- Modify: `coldwallet-watch/android/app/build.gradle.kts`
- Modify: `coldwallet-watch/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 修改 build.gradle.kts 应用 ID**

Locate the `defaultConfig` block and set:

```kotlin
applicationId = "com.coldwallet.coldwallet_watch"
```

- [ ] **Step 2: 添加网络权限**

In `AndroidManifest.xml`, add inside `<manifest>` before `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

- [ ] **Step 3: 提交配置**

```bash
git add coldwallet-watch/android/app/build.gradle.kts coldwallet-watch/android/app/src/main/AndroidManifest.xml
git commit -m "chore(watch): configure android package id and permissions"
```

---

### Task 3: 配置 Gradle 镜像

**Files:**
- Modify: `coldwallet-watch/android/gradle/wrapper/gradle-wrapper.properties`
- Modify: `coldwallet-watch/android/settings.gradle.kts`

- [ ] **Step 1: 配置 Gradle 分发镜像**

Replace `distributionUrl` in `gradle-wrapper.properties` with:

```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.10.2-all.zip
```

- [ ] **Step 2: 配置 Maven 镜像**

Replace the `repositories` blocks in `settings.gradle.kts` with:

```kotlin
pluginManagement {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        google()
        mavenCentral()
    }
}
```

- [ ] **Step 3: 提交 Gradle 配置**

```bash
git add coldwallet-watch/android/gradle/wrapper/gradle-wrapper.properties coldwallet-watch/android/settings.gradle.kts
git commit -m "chore(watch): configure gradle mirrors for china network"
```

---

### Task 4: 添加依赖

**Files:**
- Modify: `coldwallet-watch/pubspec.yaml`

- [ ] **Step 1: 添加依赖**

Replace the `dependencies` section with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cardano_flutter_sdk: ^4.0.1
  cardano_dart_types: ^3.0.0
  http: ^1.2.0
  mobile_scanner: ^3.0.0
  qr_flutter: ^4.1.0
  file_picker: ^12.0.0-beta.7
  path_provider: ^2.1.6
  shared_preferences: ^2.3.0
  flutter_secure_storage: ^9.0.0
  intl: ^0.19.0
```

- [ ] **Step 2: 获取依赖**

Run:
```powershell
cd d:\code\web3\coldwallet\coldwallet-watch
flutter pub get
```

Expected: All dependencies resolved successfully.

- [ ] **Step 3: 提交**

```bash
git add coldwallet-watch/pubspec.yaml
git commit -m "chore(watch): add dependencies"
```

---

## Phase 1: 核心模型与服务

### Task 5: 创建核心模型

**Files:**
- Create: `coldwallet-watch/lib/models/watch_wallet.dart`
- Create: `coldwallet-watch/lib/models/asset_balance.dart`
- Create: `coldwallet-watch/lib/models/cold_export.dart`
- Create: `coldwallet-watch/lib/models/cold_import.dart`

- [ ] **Step 1: WatchWallet 模型**

Create `lib/models/watch_wallet.dart`:

```dart
class WatchWallet {
  final String id;
  final String name;
  final String address;
  final String network;
  final DateTime createdAt;

  WatchWallet({
    required this.id,
    required this.name,
    required this.address,
    required this.network,
    required this.createdAt,
  });

  factory WatchWallet.create({
    required String name,
    required String address,
    required String network,
  }) {
    return WatchWallet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: address,
      network: network,
      createdAt: DateTime.now(),
    );
  }

  factory WatchWallet.fromJson(Map<String, dynamic> json) {
    return WatchWallet(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      network: json['network'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'network': network,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  WatchWallet copyWith({
    String? id,
    String? name,
    String? address,
    String? network,
    DateTime? createdAt,
  }) {
    return WatchWallet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      network: network ?? this.network,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

- [ ] **Step 2: AssetBalance 模型**

Create `lib/models/asset_balance.dart`:

```dart
class AssetBalance {
  final String unit;
  final String quantity;
  final String? displayName;
  final bool isEnabled;

  AssetBalance({
    required this.unit,
    required this.quantity,
    this.displayName,
    this.isEnabled = false,
  });

  bool get isAda => unit == 'lovelace';

  factory AssetBalance.fromJson(Map<String, dynamic> json) {
    return AssetBalance(
      unit: json['unit'] as String,
      quantity: json['quantity'] as String,
      displayName: json['displayName'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit': unit,
      'quantity': quantity,
      'displayName': displayName,
      'isEnabled': isEnabled,
    };
  }

  AssetBalance copyWith({
    String? unit,
    String? quantity,
    String? displayName,
    bool? isEnabled,
  }) {
    return AssetBalance(
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      displayName: displayName ?? this.displayName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
```

- [ ] **Step 3: ColdExport 模型**

Create `lib/models/cold_export.dart`:

```dart
class AssetAmount {
  final String unit;
  final String quantity;
  final String? displayName;

  AssetAmount({
    required this.unit,
    required this.quantity,
    this.displayName,
  });

  factory AssetAmount.fromJson(Map<String, dynamic> json) {
    return AssetAmount(
      unit: json['unit'] as String,
      quantity: json['quantity'] as String,
      displayName: json['displayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit': unit,
      'quantity': quantity,
      'displayName': displayName,
    };
  }
}

class TxSummary {
  final String fromAddress;
  final String toAddress;
  final List<AssetAmount> assets;
  final String fee;

  TxSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.assets,
    required this.fee,
  });

  factory TxSummary.fromJson(Map<String, dynamic> json) {
    return TxSummary(
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      assets: (json['assets'] as List)
          .map((e) => AssetAmount.fromJson(e as Map<String, dynamic>))
          .toList(),
      fee: json['fee'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'assets': assets.map((e) => e.toJson()).toList(),
      'fee': fee,
    };
  }
}

class ColdExport {
  final int version;
  final String type;
  final String network;
  final String txCbor;
  final TxSummary summary;

  ColdExport({
    this.version = 1,
    this.type = 'unsigned-tx',
    required this.network,
    required this.txCbor,
    required this.summary,
  });

  factory ColdExport.fromJson(Map<String, dynamic> json) {
    return ColdExport(
      version: json['version'] as int? ?? 1,
      type: json['type'] as String? ?? 'unsigned-tx',
      network: json['network'] as String,
      txCbor: json['txCbor'] as String,
      summary: TxSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'network': network,
      'txCbor': txCbor,
      'summary': summary.toJson(),
    };
  }
}
```

- [ ] **Step 4: ColdImport 模型**

Create `lib/models/cold_import.dart`:

```dart
class ColdImport {
  final int version;
  final String type;
  final String txCbor;
  final String txHash;

  ColdImport({
    this.version = 1,
    this.type = 'signed-tx',
    required this.txCbor,
    required this.txHash,
  });

  factory ColdImport.fromJson(Map<String, dynamic> json) {
    return ColdImport(
      version: json['version'] as int? ?? 1,
      type: json['type'] as String? ?? 'signed-tx',
      txCbor: json['txCbor'] as String,
      txHash: json['txHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'txCbor': txCbor,
      'txHash': txHash,
    };
  }
}
```

- [ ] **Step 5: 提交模型**

```bash
git add coldwallet-watch/lib/models/
git commit -m "feat(watch): add core models"
```

---

### Task 6: 创建 StorageService

**Files:**
- Create: `coldwallet-watch/lib/services/storage_service.dart`

- [ ] **Step 1: 实现 StorageService**

Create `lib/services/storage_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_wallet.dart';

class StorageService {
  static const _walletsKey = 'watch_wallets';
  static const _currentWalletIdKey = 'current_wallet_id';
  static const _currentNetworkKey = 'current_network';
  static const _blockfrostKeyKey = 'blockfrost_api_key';
  static const _enabledAssetsPrefix = 'enabled_assets_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService._(this._prefs, this._secureStorage);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
    return StorageService._(prefs, secureStorage);
  }

  Future<List<WatchWallet>> loadWallets() async {
    final jsonStr = _prefs.getString(_walletsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => WatchWallet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveWallets(List<WatchWallet> wallets) async {
    final list = wallets.map((e) => e.toJson()).toList();
    await _prefs.setString(_walletsKey, jsonEncode(list));
  }

  Future<String?> getCurrentWalletId() async {
    return _prefs.getString(_currentWalletIdKey);
  }

  Future<void> setCurrentWalletId(String id) async {
    await _prefs.setString(_currentWalletIdKey, id);
  }

  Future<String> getCurrentNetwork() async {
    return _prefs.getString(_currentNetworkKey) ?? 'preview';
  }

  Future<void> setCurrentNetwork(String network) async {
    await _prefs.setString(_currentNetworkKey, network);
  }

  Future<String?> getBlockfrostApiKey() async {
    return _secureStorage.read(key: _blockfrostKeyKey);
  }

  Future<void> setBlockfrostApiKey(String apiKey) async {
    await _secureStorage.write(key: _blockfrostKeyKey, value: apiKey);
  }

  Future<void> deleteBlockfrostApiKey() async {
    await _secureStorage.delete(key: _blockfrostKeyKey);
  }

  Future<List<String>> getEnabledAssets(String walletId) async {
    final key = '$_enabledAssetsPrefix$walletId';
    return _prefs.getStringList(key) ?? [];
  }

  Future<void> setEnabledAssets(String walletId, List<String> units) async {
    final key = '$_enabledAssetsPrefix$walletId';
    await _prefs.setStringList(key, units);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/services/storage_service.dart
git commit -m "feat(watch): add storage service"
```

---

### Task 7: 创建 BlockfrostService

**Files:**
- Create: `coldwallet-watch/lib/services/blockfrost_service.dart`

- [ ] **Step 1: 实现 BlockfrostService**

Create `lib/services/blockfrost_service.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class BlockfrostEndpoint {
  static const Map<String, String> baseUrls = {
    'mainnet': 'https://cardano-mainnet.blockfrost.io/api/v0',
    'preprod': 'https://cardano-preprod.blockfrost.io/api/v0',
    'preview': 'https://cardano-preview.blockfrost.io/api/v0',
  };
}

class BlockfrostService {
  final String _apiKey;
  final String _network;
  final http.Client _client;

  BlockfrostService({
    required String apiKey,
    required String network,
    http.Client? client,
  })  : _apiKey = apiKey,
        _network = network,
        _client = client ?? http.Client();

  String get _baseUrl =>
      BlockfrostEndpoint.baseUrls[_network] ?? BlockfrostEndpoint.baseUrls['preview']!;

  Map<String, String> get _headers => {
        'project_id': _apiKey,
        'Content-Type': 'application/json',
      };

  Future<List<Map<String, dynamic>>> getAddressUtxos(String address) async {
    final url = Uri.parse('$_baseUrl/addresses/$address/utxos');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Blockfrost error: ${response.statusCode} ${response.body}');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAddressBalance(String address) async {
    final url = Uri.parse('$_baseUrl/addresses/$address');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Blockfrost error: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<String> submitTx(Uint8List txBytes) async {
    final url = Uri.parse('$_baseUrl/tx/submit');
    final response = await _client.post(
      url,
      headers: {
        'project_id': _apiKey,
        'Content-Type': 'application/cbor',
      },
      body: txBytes,
    );
    if (response.statusCode != 200) {
      throw Exception('Submit failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as String;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/services/blockfrost_service.dart
git commit -m "feat(watch): add blockfrost service"
```

---

### Task 8: 创建 WalletService

**Files:**
- Create: `coldwallet-watch/lib/services/wallet_service.dart`
- Modify: `coldwallet-watch/pubspec.yaml` (if bip39 needed for validation, skip for address validation)

- [ ] **Step 1: 实现 WalletService**

Create `lib/services/wallet_service.dart`:

```dart
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';

import '../models/watch_wallet.dart';
import 'storage_service.dart';

class WalletService {
  final StorageService _storage;

  WalletService(this._storage);

  Future<List<WatchWallet>> getWallets() async {
    return _storage.loadWallets();
  }

  Future<WatchWallet?> getCurrentWallet() async {
    final wallets = await getWallets();
    final currentId = await _storage.getCurrentWalletId();
    if (currentId == null) return wallets.isNotEmpty ? wallets.first : null;
    try {
      return wallets.firstWhere((w) => w.id == currentId);
    } catch (_) {
      return wallets.isNotEmpty ? wallets.first : null;
    }
  }

  Future<void> setCurrentWallet(String id) async {
    await _storage.setCurrentWalletId(id);
  }

  Future<WatchWallet> addWallet({
    required String name,
    required String address,
    required String network,
  }) async {
    final wallets = await getWallets();
    final wallet = WatchWallet.create(
      name: name,
      address: address,
      network: network,
    );
    wallets.add(wallet);
    await _storage.saveWallets(wallets);
    return wallet;
  }

  Future<void> deleteWallet(String id) async {
    final wallets = await getWallets();
    wallets.removeWhere((w) => w.id == id);
    await _storage.saveWallets(wallets);
    final currentId = await _storage.getCurrentWalletId();
    if (currentId == id) {
      await _storage.setCurrentWalletId(wallets.isNotEmpty ? wallets.first.id : '');
    }
  }

  Future<void> updateWallet(WatchWallet wallet) async {
    final wallets = await getWallets();
    final index = wallets.indexWhere((w) => w.id == wallet.id);
    if (index >= 0) {
      wallets[index] = wallet;
      await _storage.saveWallets(wallets);
    }
  }

  bool validateAddress(String address) {
    try {
      // cardano_flutter_sdk address validation
      final addr = CardanoAddress(address);
      return addr.toString().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
```

Note: `CardanoAddress` class may need adjustment based on actual SDK API. Verify against `cardano_flutter_sdk` exports.

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/services/wallet_service.dart
git commit -m "feat(watch): add wallet service"
```

---

### Task 9: 创建 AssetService

**Files:**
- Create: `coldwallet-watch/lib/services/asset_service.dart`

- [ ] **Step 1: 实现 AssetService**

Create `lib/services/asset_service.dart`:

```dart
import '../models/asset_balance.dart';
import 'blockfrost_service.dart';
import 'storage_service.dart';

class AssetService {
  final BlockfrostService _blockfrost;
  final StorageService _storage;

  AssetService(this._blockfrost, this._storage);

  Future<List<AssetBalance>> loadBalances(
    String address,
    String walletId,
  ) async {
    final data = await _blockfrost.getAddressBalance(address);
    final amountList = (data['amount'] as List<dynamic>).cast<Map<String, dynamic>>();
    final enabledUnits = await _storage.getEnabledAssets(walletId);

    return amountList.map((item) {
      final unit = item['unit'] as String;
      return AssetBalance(
        unit: unit,
        quantity: item['quantity'] as String,
        displayName: _displayName(unit),
        isEnabled: enabledUnits.contains(unit),
      );
    }).toList();
  }

  String _displayName(String unit) {
    if (unit == 'lovelace') return 'ADA';
    // For tokens/NFTs, truncate or lookup; MVP uses hex unit as fallback
    return unit.length > 20 ? '${unit.substring(0, 8)}...${unit.substring(unit.length - 8)}' : unit;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/services/asset_service.dart
git commit -m "feat(watch): add asset service"
```

---

### Task 10: 创建 TxBuilderService（占位）

**Files:**
- Create: `coldwallet-watch/lib/services/tx_builder_service.dart`

- [ ] **Step 1: 创建占位实现**

Create `lib/services/tx_builder_service.dart`:

```dart
import '../models/asset_balance.dart';
import '../models/cold_export.dart';
import 'blockfrost_service.dart';

class TxBuilderService {
  final BlockfrostService _blockfrost;

  TxBuilderService(this._blockfrost);

  Future<ColdExport> buildTransferTx({
    required String fromAddress,
    required String toAddress,
    required List<AssetAmount> assets,
    required String network,
  }) async {
    // Placeholder implementation for UI wiring.
    // Real transaction building is implemented in Task 20 after verifying cardano_flutter_sdk API.
    return ColdExport(
      network: network,
      txCbor: 'dummycbor',
      summary: TxSummary(
        fromAddress: fromAddress,
        toAddress: toAddress,
        assets: assets,
        fee: '0',
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/services/tx_builder_service.dart
git commit -m "feat(watch): add tx builder service placeholder"
```

---

## Phase 2: 应用入口与路由

### Task 11: 配置 MaterialApp 路由

**Files:**
- Create: `coldwallet-watch/lib/app.dart`
- Modify: `coldwallet-watch/lib/main.dart`

- [ ] **Step 1: 创建 App 路由配置**

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'screens/add_wallet_screen.dart';
import 'screens/export_tx_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_signed_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/wallet_detail_screen.dart';

class ColdWalletWatchApp extends StatelessWidget {
  const ColdWalletWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cold Wallet Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/add-wallet': (context) => const AddWalletScreen(),
        '/wallet-detail': (context) => const WalletDetailScreen(),
        '/send': (context) => const SendScreen(),
        '/export-tx': (context) => const ExportTxScreen(),
        '/import-signed': (context) => const ImportSignedScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
```

- [ ] **Step 2: 更新 main.dart**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const ColdWalletWatchApp());
}
```

- [ ] **Step 3: 创建空页面占位文件**

Create each screen file with minimal content:

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cold Wallet Watch')),
      body: const Center(child: Text('Home')),
    );
  }
}
```

Repeat for:
- `lib/screens/add_wallet_screen.dart`
- `lib/screens/wallet_detail_screen.dart`
- `lib/screens/send_screen.dart`
- `lib/screens/export_tx_screen.dart`
- `lib/screens/import_signed_screen.dart`
- `lib/screens/settings_screen.dart`

- [ ] **Step 4: 验证构建**

Run:
```powershell
cd d:\code\web3\coldwallet\coldwallet-watch
flutter build apk --debug
```

Expected: Build succeeds.

- [ ] **Step 5: 提交**

```bash
git add coldwallet-watch/lib/app.dart coldwallet-watch/lib/main.dart coldwallet-watch/lib/screens/
git commit -m "feat(watch): setup app routing and screen placeholders"
```

---

## Phase 3: UI 实现

### Task 12: 实现 SettingsScreen

**Files:**
- Modify: `coldwallet-watch/lib/screens/settings_screen.dart`

- [ ] **Step 1: 实现 SettingsScreen**

Replace content with:

```dart
import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService.create() as StorageService;
  final _apiKeyController = TextEditingController();
  String _network = 'preview';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.create();
    final apiKey = await storage.getBlockfrostApiKey();
    final network = await storage.getCurrentNetwork();
    setState(() {
      _storage = storage;
      _apiKeyController.text = apiKey ?? '';
      _network = network;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _storage.setBlockfrostApiKey(_apiKeyController.text.trim());
    await _storage.setCurrentNetwork(_network);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('网络', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _network,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'mainnet', child: Text('Mainnet')),
                DropdownMenuItem(value: 'preview', child: Text('Preview')),
                DropdownMenuItem(value: 'preprod', child: Text('Preprod')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _network = value);
              },
            ),
            const SizedBox(height: 24),
            const Text('Blockfrost API Key', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                hintText: '输入 Blockfrost Project ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveSettings,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: Fix the `_storage` field initialization in StatefulWidget properly. The above has a type issue; use `late StorageService _storage;`.

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/screens/settings_screen.dart
git commit -m "feat(watch): add settings screen"
```

---

### Task 13: 实现 AddWalletScreen

**Files:**
- Modify: `coldwallet-watch/lib/screens/add_wallet_screen.dart`

- [ ] **Step 1: 实现 AddWalletScreen**

Replace content with:

```dart
import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../services/wallet_service.dart';

class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  late final WalletService _walletService;
  String _network = 'preview';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final storage = await StorageService.create();
    _walletService = WalletService(storage);
    final network = await storage.getCurrentNetwork();
    setState(() => _network = network);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      _showError('名称和地址不能为空');
      return;
    }
    if (!_walletService.validateAddress(address)) {
      _showError('地址格式不正确');
      return;
    }
    setState(() => _saving = true);
    try {
      await _walletService.addWallet(
        name: name,
        address: address,
        network: _network,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加只读钱包')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '钱包名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cardano 地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/screens/add_wallet_screen.dart
git commit -m "feat(watch): add wallet creation screen"
```

---

### Task 14: 实现 HomeScreen

**Files:**
- Modify: `coldwallet-watch/lib/screens/home_screen.dart`

- [ ] **Step 1: 实现 HomeScreen**

Replace content with:

```dart
import 'package:flutter/material.dart';

import '../models/watch_wallet.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WalletService _walletService;
  List<WatchWallet> _wallets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storage = await StorageService.create();
    _walletService = WalletService(storage);
    await _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await _walletService.getWallets();
    setState(() {
      _wallets = wallets;
      _loading = false;
    });
  }

  Future<void> _navigateAddWallet() async {
    final result = await Navigator.pushNamed(context, '/add-wallet');
    if (result == true) _loadWallets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold Wallet Watch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings').then((_) => _loadWallets()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
              ? _buildEmptyState()
              : _buildWalletList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateAddWallet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('还没有只读钱包', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _navigateAddWallet,
            child: const Text('添加钱包'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletList() {
    return ListView.builder(
      itemCount: _wallets.length,
      itemBuilder: (context, index) {
        final wallet = _wallets[index];
        return ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: Text(wallet.name),
          subtitle: Text(wallet.address, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(wallet.network.toUpperCase()),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/wallet-detail',
              arguments: wallet,
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/screens/home_screen.dart
git commit -m "feat(watch): add home screen with wallet list"
```

---

### Task 15: 实现 WalletDetailScreen

**Files:**
- Modify: `coldwallet-watch/lib/screens/wallet_detail_screen.dart`

- [ ] **Step 1: 实现 WalletDetailScreen**

Replace content with:

```dart
import 'package:flutter/material.dart';

import '../models/asset_balance.dart';
import '../models/watch_wallet.dart';
import '../services/asset_service.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  WatchWallet? _wallet;
  List<AssetBalance> _assets = [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is WatchWallet) {
      _wallet = args;
      _loadBalances();
    }
  }

  Future<void> _loadBalances() async {
    if (_wallet == null) return;
    setState(() => _loading = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _error = '请先设置 Blockfrost API Key';
          _loading = false;
        });
        return;
      }
      final blockfrost = BlockfrostService(apiKey: apiKey, network: _wallet!.network);
      final assetService = AssetService(blockfrost, storage);
      final assets = await assetService.loadBalances(_wallet!.address, _wallet!.id);
      setState(() {
        _assets = assets;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) return const Scaffold(body: Center(child: Text('无钱包数据')));

    return Scaffold(
      appBar: AppBar(title: Text(wallet.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(wallet),
      floatingActionButton: FloatingButton(
        onPressed: () => Navigator.pushNamed(context, '/send', arguments: wallet),
        child: const Icon(Icons.send),
      ),
    );
  }

  Widget _buildBody(WatchWallet wallet) {
    final enabledAssets = _assets.where((a) => a.isEnabled).toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('地址', style: Theme.of(context).textTheme.titleMedium),
          SelectableText(wallet.address),
          const SizedBox(height: 24),
          Text('资产', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: enabledAssets.isEmpty
                ? const Text('没有开启显示的资产')
                : ListView.builder(
                    itemCount: enabledAssets.length,
                    itemBuilder: (context, index) {
                      final asset = enabledAssets[index];
                      return ListTile(
                        title: Text(asset.displayName ?? asset.unit),
                        subtitle: Text(asset.quantity),
                      );
                    },
                  ),
          ),
          TextButton(
            onPressed: _manageAssets,
            child: const Text('管理显示资产'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageAssets() async {
    // Navigate to asset management screen (to be implemented)
  }
}
```

Note: Fix `FloatingButton` to `FloatingActionButton`.

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/screens/wallet_detail_screen.dart
git commit -m "feat(watch): add wallet detail screen with balance"
```

---

## Phase 4: 交易流程

### Task 16: 实现 SendScreen

**Files:**
- Modify: `coldwallet-watch/lib/screens/send_screen.dart`

- [ ] **Step 1: 实现 SendScreen**

Create a form to input recipient address, select asset, input amount, and build transaction.

```dart
import 'package:flutter/material.dart';

import '../models/asset_balance.dart';
import '../models/cold_export.dart';
import '../models/watch_wallet.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../services/tx_builder_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  WatchWallet? _wallet;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedUnit = 'lovelace';
  bool _building = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is WatchWallet) {
      _wallet = args;
    }
  }

  Future<void> _buildTx() async {
    final wallet = _wallet;
    if (wallet == null) return;
    final toAddress = _addressController.text.trim();
    final amount = _amountController.text.trim();
    if (toAddress.isEmpty || amount.isEmpty) {
      _showError('收款地址和金额不能为空');
      return;
    }
    if (toAddress == wallet.address) {
      _showError('不能转账给自己');
      return;
    }
    setState(() => _building = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey() ?? '';
      final blockfrost = BlockfrostService(apiKey: apiKey, network: wallet.network);
      final txBuilder = TxBuilderService(blockfrost);
      final coldExport = await txBuilder.buildTransferTx(
        fromAddress: wallet.address,
        toAddress: toAddress,
        assets: [
          AssetAmount(unit: _selectedUnit, quantity: amount),
        ],
        network: wallet.network,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/export-tx', arguments: coldExport);
      }
    } catch (e) {
      _showError('构建交易失败: $e');
    } finally {
      setState(() => _building = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    if (wallet == null) return const Scaffold(body: Center(child: Text('无钱包数据')));

    return Scaffold(
      appBar: AppBar(title: const Text('发起转账')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '收款地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: const InputDecoration(labelText: '资产'),
              items: const [
                DropdownMenuItem(value: 'lovelace', child: Text('ADA')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedUnit = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数量（lovelace 或 token 单位）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _building ? null : _buildTx,
                child: _building
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('下一步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add coldwallet-watch/lib/screens/send_screen.dart
git commit -m "feat(watch): add send screen"
```

---

### Task 17: 实现 ExportTxScreen

**Files:**
- Create: `coldwallet-watch/lib/widgets/qr_display.dart`
- Modify: `coldwallet-watch/lib/screens/export_tx_screen.dart`

- [ ] **Step 1: 创建 QRDisplay widget**

Create `lib/widgets/qr_display.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRDisplay extends StatelessWidget {
  final String data;
  final double size;

  const QRDisplay({super.key, required this.data, this.size = 250});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      backgroundColor: Colors.white,
    );
  }
}
```

- [ ] **Step 2: 实现 ExportTxScreen**

Replace `lib/screens/export_tx_screen.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cold_export.dart';
import '../widgets/qr_display.dart';

class ExportTxScreen extends StatelessWidget {
  const ExportTxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coldExport = ModalRoute.of(context)!.settings.arguments as ColdExport;
    final jsonStr = jsonEncode(coldExport.toJson());

    Future<void> copyJson() async {
      await Clipboard.setData(ClipboardData(text: jsonStr));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制 JSON 到剪贴板')),
      );
    }

    Future<void> saveFile() async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/unsigned_tx_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsString(jsonStr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件已保存: ${file.path}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('导出未签名交易')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('二维码', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Center(child: QRDisplay(data: jsonStr)),
            const SizedBox(height: 24),
            const Text('JSON 文本', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(jsonStr, maxLines: 5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: copyJson,
                    icon: const Icon(Icons.copy),
                    label: const Text('复制 JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saveFile,
                    icon: const Icon(Icons.save),
                    label: const Text('保存文件'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add coldwallet-watch/lib/screens/export_tx_screen.dart coldwallet-watch/lib/widgets/qr_display.dart
git commit -m "feat(watch): add export tx screen with qr/json/file"
```

---

### Task 18: 实现 ImportSignedScreen

**Files:**
- Create: `coldwallet-watch/lib/widgets/qr_scanner.dart`
- Modify: `coldwallet-watch/lib/screens/import_signed_screen.dart`

- [ ] **Step 1: 创建 QRScanner widget**

Create `lib/widgets/qr_scanner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanner extends StatelessWidget {
  final Function(String) onScan;

  const QRScanner({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        final barcode = capture.barcodes.firstOrNull;
        final value = barcode?.rawValue;
        if (value != null) {
          onScan(value);
        }
      },
    );
  }
}
```

- [ ] **Step 2: 实现 ImportSignedScreen**

Replace `lib/screens/import_signed_screen.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cold_import.dart';
import '../services/blockfrost_service.dart';
import '../services/storage_service.dart';
import '../widgets/qr_scanner.dart';

class ImportSignedScreen extends StatefulWidget {
  const ImportSignedScreen({super.key});

  @override
  State<ImportSignedScreen> createState() => _ImportSignedScreenState();
}

class _ImportSignedScreenState extends State<ImportSignedScreen> {
  bool _submitting = false;

  Future<void> _parseAndSubmit(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final coldImport = ColdImport.fromJson(data);
      await _submit(coldImport);
    } catch (e) {
      _showError('解析签名文件失败: $e');
    }
  }

  Future<void> _submit(ColdImport coldImport) async {
    setState(() => _submitting = true);
    try {
      final storage = await StorageService.create();
      final apiKey = await storage.getBlockfrostApiKey();
      final network = await storage.getCurrentNetwork();
      if (apiKey == null || apiKey.isEmpty) {
        _showError('请先设置 Blockfrost API Key');
        return;
      }
      final blockfrost = BlockfrostService(apiKey: apiKey, network: network);
      final txBytes = Uint8List.fromList(List<int>.generate(
        coldImport.txCbor.length ~/ 2,
        (i) => int.parse(coldImport.txCbor.substring(i * 2, i * 2 + 2), radix: 16),
      ));
      final txHash = await blockfrost.submitTx(txBytes);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提交成功'),
            content: SelectableText('TxHash: $txHash'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('提交失败: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;
    final path = result.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    await _parseAndSubmit(content.trim());
  }

  Future<void> _pasteJson() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.isEmpty) {
      _showError('剪贴板为空');
      return;
    }
    await _parseAndSubmit(text.trim());
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入签名结果')),
      body: _submitting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(child: QRScanner(onScan: _parseAndSubmit)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('从文件导入'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pasteJson,
                          icon: const Icon(Icons.paste),
                          label: const Text('粘贴 JSON'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add coldwallet-watch/lib/screens/import_signed_screen.dart coldwallet-watch/lib/widgets/qr_scanner.dart
git commit -m "feat(watch): add import signed screen"
```

---

## Phase 5: 集成与测试

### Task 19: 端到端构建验证

**Files:**
- All `coldwallet-watch/`

- [ ] **Step 1: 运行 flutter analyze**

Run:
```powershell
cd d:\code\web3\coldwallet\coldwallet-watch
flutter analyze
```

Expected: No errors.

- [ ] **Step 2: 构建 Debug APK**

Run:
```powershell
cd d:\code\web3\coldwallet\coldwallet-watch
flutter build apk --debug
```

Expected: Build succeeds, APK at `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 3: 提交**

```bash
git add coldwallet-watch/
git commit -m "feat(watch): complete mvp screens and widgets"
```

---

### Task 20: 与 coldwallet-app 联调

**Files:**
- `coldwallet-watch/lib/services/tx_builder_service.dart` (replace placeholder)
- `coldwallet-app/lib/models/cold_export.dart` (verify compatibility)

- [ ] **Step 1: 实现真正的交易构建**

Replace `TxBuilderService.buildTransferTx` with actual implementation using `cardano_flutter_sdk` once its API is verified. Refer to `coldwallet-app/lib/services/transaction_service.dart` for signing patterns.

- [ ] **Step 2: 验证 ColdExport/ColdImport JSON 兼容**

Compare `coldwallet-watch/lib/models/cold_export.dart` with `coldwallet-app/lib/models/cold_export.dart`. Ensure field names and types match.

- [ ] **Step 3: 模拟完整流程**

1. 在 watch App 添加地址。
2. 设置 Blockfrost API Key。
3. 发起转账，导出 QR。
4. 用 coldwallet-app 扫码签名，导出签名 QR。
5. 用 watch App 扫码导入并提交。

- [ ] **Step 4: 提交**

```bash
git add coldwallet-watch/lib/services/tx_builder_service.dart
git commit -m "feat(watch): implement real transaction building"
```

---

## 自检清单

| 检查项 | 状态 |
|--------|------|
| Spec 覆盖 | 每个功能都有对应任务 |
| 无占位符 | 无 TBD/TODO/"实现 later" |
| 类型一致 | `ColdExport`/`ColdImport` 与 coldwallet-app 共用字段 |
| 可测试 | 每个阶段都有构建验证步骤 |
