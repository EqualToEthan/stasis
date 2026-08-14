import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/wallet_info.dart';

/// 安全存储服务（多钱包版）
///
/// 所有敏感数据（助记词、PIN、钱包列表）都通过 Android Keystore 加密存储。
/// 冷钱包场景下 App 完全离线，密钥不会离开设备。
///
/// 存储 Key 规划：
/// - `wallet_list`            钱包元数据列表 JSON
/// - `wallet_{id}_mnemonic`   按 ID 隔离的助记词
/// - `current_wallet_id`      当前选中钱包 ID
/// - `current_network`        全局网络 mainnet / testnet
/// - `wallet_pin_hash`        全局 PIN
class SecureStorageService {
  static const _walletListKey = 'wallet_list';
  static const _pinHashKey = 'wallet_pin_hash';
  static const _currentWalletIdKey = 'current_wallet_id';
  static const _currentNetworkKey = 'current_network';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── 钱包列表 ───────────────────────────────────────────────

  /// 加载钱包列表
  Future<List<WalletInfo>> loadWalletList() async {
    final raw = await _storage.read(key: _walletListKey);
    if (raw == null || raw.isEmpty) return [];
    return WalletListCodec.decode(raw);
  }

  /// 保存钱包列表（覆盖写入）
  Future<void> saveWalletList(List<WalletInfo> wallets) async {
    await _storage.write(
      key: _walletListKey,
      value: WalletListCodec.encode(wallets),
    );
  }

  // ─── 助记词（按钱包 ID 隔离） ─────────────────────────────

  /// 保存指定钱包的助记词
  Future<void> saveMnemonic(String walletId, String mnemonic) async {
    await _storage.write(key: 'wallet_${walletId}_mnemonic', value: mnemonic);
  }

  /// 读取指定钱包的助记词
  Future<String?> readMnemonic(String walletId) async {
    return await _storage.read(key: 'wallet_${walletId}_mnemonic');
  }

  /// 删除指定钱包的助记词
  Future<void> deleteMnemonic(String walletId) async {
    await _storage.delete(key: 'wallet_${walletId}_mnemonic');
  }

  // ─── 当前选中钱包 ─────────────────────────────────────────

  Future<void> setCurrentWalletId(String id) async {
    await _storage.write(key: _currentWalletIdKey, value: id);
  }

  Future<String?> getCurrentWalletId() async {
    return await _storage.read(key: _currentWalletIdKey);
  }

  // ─── 全局网络 ──────────────────────────────────────────────

  Future<void> setCurrentNetwork(String network) async {
    await _storage.write(key: _currentNetworkKey, value: network);
  }

  Future<String> getCurrentNetwork() async {
    return await _storage.read(key: _currentNetworkKey) ?? 'testnet';
  }

  // ─── PIN（全局） ───────────────────────────────────────────

  Future<void> savePin(String pin) async {
    // TODO: 改为保存 argon2 或 PBKDF2 哈希
    await _storage.write(key: _pinHashKey, value: pin);
  }

  Future<String?> readPinHash() async {
    return await _storage.read(key: _pinHashKey);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await readPinHash();
    // TODO: 改为哈希比较
    return stored == pin;
  }

  Future<bool> hasPin() async {
    final pin = await readPinHash();
    return pin != null && pin.isNotEmpty;
  }

  // ─── 清空 ──────────────────────────────────────────────────

  /// 清空所有存储数据（含所有钱包助记词、PIN、列表、网络设置）
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
