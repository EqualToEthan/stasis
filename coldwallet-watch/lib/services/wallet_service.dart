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
    String? stakeAddress,
    required String chainFamily,
    String? chainId,
    required String network,
  }) async {
    final wallets = await getWallets();
    final wallet = WatchWallet.create(
      name: name,
      address: address,
      stakeAddress: stakeAddress,
      chainFamily: chainFamily,
      chainId: chainId,
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

  /// 校验地址格式（链感知）
  ///
  /// 根据 [chainFamily] 选择对应的校验规则：
  /// - cardano: bech32 前缀（addr1 / addr_test1）+ 最小长度 50
  /// - evm: 0x 前缀 + 40 位 hex 字符（总长度 42）
  bool validateAddress(String address, String chainFamily) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;

    switch (chainFamily) {
      case 'cardano':
        final validPrefix =
            trimmed.startsWith('addr1') || trimmed.startsWith('addr_test1');
        return validPrefix && trimmed.length >= 50;
      case 'evm':
        if (!trimmed.startsWith('0x') || trimmed.length != 42) return false;
        // 检查 0x 后是否全是合法 hex
        final hexPart = trimmed.substring(2);
        return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hexPart);
      default:
        return false;
    }
  }

  /// 从地址格式自动推断链族
  ///
  /// - 以 'addr1' 或 'addr_test1' 开头 → 'cardano'
  /// - 以 '0x' + 40 hex 字符 → 'evm'
  /// - 无法识别 → null
  String? detectChainFamily(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('addr1') || trimmed.startsWith('addr_test1')) {
      return 'cardano';
    }
    if (trimmed.startsWith('0x') && trimmed.length == 42) {
      final hexPart = trimmed.substring(2);
      if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hexPart)) {
        return 'evm';
      }
    }
    return null;
  }
}
