import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

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
/// - `wallet_pin_hash`        全局 PIN（PBKDF2 哈希）
/// - `wallet_{id}_passphrase` 按 ID 隔离的 BIP-39 密码短语
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

  // ─── PIN（全局，PBKDF2-HMAC-SHA256 哈希存储） ─────────────

  /// 保存 PIN 的 PBKDF2 哈希值
  ///
  /// 使用随机 16 字节盐 + PBKDF2-HMAC-SHA256（100,000 次迭代），
  /// 存储格式为 `hex(salt):hex(hash)`，不保存 PIN 明文。
  Future<void> savePin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<String?> readPinHash() async {
    return await _storage.read(key: _pinHashKey);
  }

  /// 验证 PIN 是否与存储的哈希匹配
  ///
  /// 从存储中取出盐值，用相同参数重新计算 PBKDF2 哈希后比较。
  Future<bool> verifyPin(String pin) async {
    final stored = await readPinHash();
    if (stored == null || stored.isEmpty) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final hash = _hashPin(pin, saltHex: parts[0]);
    return stored == hash;
  }

  Future<bool> hasPin() async {
    final pin = await readPinHash();
    return pin != null && pin.isNotEmpty;
  }

  /// PBKDF2-HMAC-SHA256 哈希 PIN
  ///
  /// [pin] 用户输入的 PIN 明文
  /// [saltHex] 可选的盐值 hex 字符串，为 null 时自动生成 16 字节随机盐
  /// 返回格式：`hex(salt):hex(hash)`
  static String _hashPin(String pin, {String? saltHex}) {
    final salt = saltHex != null
        ? Uint8List.fromList(HEX.decode(saltHex))
        : _generateSalt();
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, 32));
    final result = Uint8List(32);
    derivator.deriveKey(Uint8List.fromList(pin.codeUnits), 0, result, 0);
    return '${HEX.encode(salt)}:${HEX.encode(result)}';
  }

  /// 生成 16 字节安全随机盐
  static Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  // ─── 密码短语（BIP-39 passphrase，按钱包 ID 隔离） ────────

  /// 保存指定钱包的 BIP-39 密码短语
  Future<void> savePassphrase(String walletId, String passphrase) async {
    await _storage.write(
      key: 'wallet_${walletId}_passphrase',
      value: passphrase,
    );
  }

  /// 读取指定钱包的密码短语，未设置时返回 null
  Future<String?> readPassphrase(String walletId) async {
    return await _storage.read(key: 'wallet_${walletId}_passphrase');
  }

  /// 删除指定钱包的密码短语
  Future<void> deletePassphrase(String walletId) async {
    await _storage.delete(key: 'wallet_${walletId}_passphrase');
  }

  // ─── 清空 ──────────────────────────────────────────────────

  /// 清空所有存储数据（含所有钱包助记词、密码短语、PIN、列表、网络设置）
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
