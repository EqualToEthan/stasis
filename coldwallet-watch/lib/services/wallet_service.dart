import '../models/watch_wallet.dart';
import 'storage_service.dart';

/// 钱包管理服务
///
/// 提供只读钱包的增删改查、当前钱包切换和地址验证功能。
class WalletService {
  final StorageService _storage;

  WalletService(this._storage);

  /// 获取所有钱包列表
  Future<List<WatchWallet>> getWallets() async {
    return _storage.loadWallets();
  }

  /// 获取当前选中的钱包
  ///
  /// 若无当前钱包则自动选中第一个。
  Future<WatchWallet?> getCurrentWallet() async {
    final wallets = await getWallets();
    if (wallets.isEmpty) return null;
    final currentId = await _storage.getCurrentWalletId();
    if (currentId != null && currentId.isNotEmpty) {
      final match = wallets.where((w) => w.id == currentId).firstOrNull;
      if (match != null) return match;
    }
    final first = wallets.first;
    await _storage.setCurrentWalletId(first.id);
    return first;
  }

  Future<void> setCurrentWallet(String id) async {
    await _storage.setCurrentWalletId(id);
  }

  /// 添加新钱包并保存到存储
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

  /// 删除钱包并自动切换当前钱包
  Future<void> deleteWallet(String id) async {
    final wallets = await getWallets();
    wallets.removeWhere((w) => w.id == id);
    await _storage.saveWallets(wallets);
    final currentId = await _storage.getCurrentWalletId();
    if (currentId == id) {
      await _storage.setCurrentWalletId(
        wallets.isNotEmpty ? wallets.first.id : '',
      );
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

  /// 校验 Cardano 地址格式
  ///
  /// 检查 bech32 前缀（addr1 / addr_test1）和最小长度。
  bool validateAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;
    // Basic Cardano address validation: bech32 prefix + sufficient length.
    final validPrefix =
        trimmed.startsWith('addr1') || trimmed.startsWith('addr_test1');
    return validPrefix && trimmed.length >= 50;
  }
}
