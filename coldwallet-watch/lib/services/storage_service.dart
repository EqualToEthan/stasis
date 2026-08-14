import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_wallet.dart';

/// 本地存储服务
///
/// 钱包列表、当前钱包、启用资产等用 SharedPreferences 明文存储，
/// Blockfrost API Key 用 FlutterSecureStorage 加密存储。
class StorageService {
  static const _walletsKey = 'watch_wallets';
  static const _currentWalletIdKey = 'current_wallet_id';
  static const _blockfrostKeyKey = 'blockfrost_api_key';
  static const _enabledAssetsPrefix = 'enabled_assets_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService._(this._prefs, this._secureStorage);

  /// 工厂方法，初始化 SharedPreferences 和 SecureStorage 实例
  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
    return StorageService._(prefs, secureStorage);
  }

  /// 加载所有只读钱包列表
  Future<List<WatchWallet>> loadWallets() async {
    final jsonStr = _prefs.getString(_walletsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => WatchWallet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 保存钱包列表（覆盖写入）
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
    return 'preview';
  }

  Future<void> setCurrentNetwork(String network) async {
    // Network is fixed to preview testnet; this setter is kept for compatibility.
  }

  /// 获取 Blockfrost API Key（从安全存储）
  Future<String?> getBlockfrostApiKey() async {
    return _secureStorage.read(key: _blockfrostKeyKey);
  }

  /// 保存 Blockfrost API Key 到安全存储
  Future<void> setBlockfrostApiKey(String apiKey) async {
    await _secureStorage.write(key: _blockfrostKeyKey, value: apiKey);
  }

  Future<void> deleteBlockfrostApiKey() async {
    await _secureStorage.delete(key: _blockfrostKeyKey);
  }

  /// 获取指定钱包用户启用的资产列表
  Future<List<String>> getEnabledAssets(String walletId) async {
    final key = '$_enabledAssetsPrefix$walletId';
    return _prefs.getStringList(key) ?? [];
  }

  Future<void> setEnabledAssets(String walletId, List<String> units) async {
    final key = '$_enabledAssetsPrefix$walletId';
    await _prefs.setStringList(key, units);
  }
}
