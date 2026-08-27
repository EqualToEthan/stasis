import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/services/storage_service.dart';

/// 测试中共享的 [StorageService] 内存替身。
///
/// 避免在 widget/service 测试中调用真实的 SharedPreferences / SecureStorage。
/// 所有状态均可通过构造函数初始化，并在测试运行中被读取或修改。
class FakeStorageService implements StorageService {
  List<WatchWallet> _wallets;
  String? _currentWalletId;
  String? _blockfrostApiKey;
  final Map<String, List<String>> _enabledAssets;
  final Map<String, String?> _evmRpcUrls;
  final Map<String, List<String>> _evmTokenContracts;

  FakeStorageService({
    List<WatchWallet> wallets = const [],
    String? currentWalletId,
    String? blockfrostApiKey,
    Map<String, List<String>> enabledAssets = const {},
    Map<String, String?> evmRpcUrls = const {},
    Map<String, List<String>> evmTokenContracts = const {},
  }) : _wallets = wallets.toList(),
       _currentWalletId = currentWalletId,
       _blockfrostApiKey = blockfrostApiKey,
       _enabledAssets = Map.from(enabledAssets),
       _evmRpcUrls = Map.from(evmRpcUrls),
       _evmTokenContracts = Map.from(evmTokenContracts);

  @override
  Future<List<WatchWallet>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WatchWallet> wallets) async {
    _wallets = wallets.toList();
  }

  @override
  Future<String?> getCurrentWalletId() async => _currentWalletId;

  @override
  Future<void> setCurrentWalletId(String id) async {
    _currentWalletId = id;
  }

  @override
  Future<String?> getBlockfrostApiKey() async => _blockfrostApiKey;

  @override
  Future<void> setBlockfrostApiKey(String apiKey) async {
    _blockfrostApiKey = apiKey;
  }

  @override
  Future<void> deleteBlockfrostApiKey() async {
    _blockfrostApiKey = null;
  }

  @override
  Future<List<String>> getEnabledAssets(String walletId) async =>
      _enabledAssets[walletId] ?? [];

  @override
  Future<void> setEnabledAssets(String walletId, List<String> assets) async {
    _enabledAssets[walletId] = assets.toList();
  }

  @override
  Future<String?> getEvmRpcUrl(String chainId) async => _evmRpcUrls[chainId];

  @override
  Future<void> setEvmRpcUrl(String chainId, String? url) async {
    if (url == null || url.isEmpty) {
      _evmRpcUrls.remove(chainId);
    } else {
      _evmRpcUrls[chainId] = url;
    }
  }

  @override
  Future<List<String>> getEvmTokenContracts(String chainId) async =>
      _evmTokenContracts[chainId] ?? [];

  @override
  Future<void> setEvmTokenContracts(
    String chainId,
    List<String> contracts,
  ) async {
    _evmTokenContracts[chainId] = contracts.toList();
  }
}
