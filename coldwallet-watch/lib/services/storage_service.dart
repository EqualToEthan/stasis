import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/watch_wallet.dart';

/// 本地存储服务
///
/// 钱包列表、当前钱包、启用资产等用 SharedPreferences 明文存储，
/// Blockfrost API Key 用 FlutterSecureStorage 加密存储。
class StorageService {
  static const _walletsKey = 'watch_wallets';
  static const _currentWalletIdKey = 'current_wallet_id';

  /// 测试网 Blockfrost key（向后兼容旧 key 名称）
  static const _blockfrostKeyTestnet = 'blockfrost_api_key';

  /// 主网 Blockfrost key
  static const _blockfrostKeyMainnet = 'blockfrost_api_key_mainnet';
  static const _enabledAssetsPrefix = 'enabled_assets_';
  static const _evmRpcUrlPrefix = 'evm_rpc_url_';
  static const _evmTokenContractsPrefix = 'evm_token_contracts_';

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

  /// 获取当前网络对应的 Blockfrost key 存储键名
  String get _blockfrostKey =>
      AppConfig.isMainnet ? _blockfrostKeyMainnet : _blockfrostKeyTestnet;

  /// 获取 Blockfrost API Key（从安全存储）
  ///
  /// 根据 [AppConfig.isMainnet] 自动选择测试网或主网 key。
  Future<String?> getBlockfrostApiKey() async {
    return _secureStorage.read(key: _blockfrostKey);
  }

  /// 保存 Blockfrost API Key 到安全存储
  Future<void> setBlockfrostApiKey(String apiKey) async {
    await _secureStorage.write(key: _blockfrostKey, value: apiKey);
  }

  Future<void> deleteBlockfrostApiKey() async {
    await _secureStorage.delete(key: _blockfrostKey);
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

  /// 获取指定 EVM 链的自定义 RPC URL。
  ///
  /// 返回 null 时表示使用 [EvmRpcConfig] 中的默认节点。
  Future<String?> getEvmRpcUrl(String chainId) async {
    final key = '$_evmRpcUrlPrefix$chainId';
    return _prefs.getString(key);
  }

  /// 保存指定 EVM 链的自定义 RPC URL。
  ///
  /// 传入 null 或空字符串时删除已保存的覆盖值。
  Future<void> setEvmRpcUrl(String chainId, String? url) async {
    final key = '$_evmRpcUrlPrefix$chainId';
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, url.trim());
    }
  }

  /// 获取指定 EVM 链下用户手动添加的 ERC-20 合约地址列表。
  Future<List<String>> getEvmTokenContracts(String chainId) async {
    final key = '$_evmTokenContractsPrefix$chainId';
    return _prefs.getStringList(key) ?? [];
  }

  /// 保存指定 EVM 链下用户手动添加的 ERC-20 合约地址列表。
  Future<void> setEvmTokenContracts(
    String chainId,
    List<String> contracts,
  ) async {
    final key = '$_evmTokenContractsPrefix$chainId';
    await _prefs.setStringList(key, contracts);
  }
}
