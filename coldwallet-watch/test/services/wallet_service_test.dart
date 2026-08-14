import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import 'package:coldwallet_watch/services/wallet_service.dart';

class FakeStorageService implements StorageService {
  List<WatchWallet> _wallets = [];
  String? _currentWalletId;

  @override
  Future<List<WatchWallet>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WatchWallet> wallets) async {
    _wallets = wallets;
  }

  @override
  Future<String?> getCurrentWalletId() async => _currentWalletId;

  @override
  Future<void> setCurrentWalletId(String id) async {
    _currentWalletId = id;
  }

  @override
  Future<String> getCurrentNetwork() async => 'preview';

  @override
  Future<void> setCurrentNetwork(String network) async {}

  @override
  Future<String?> getBlockfrostApiKey() async => null;

  @override
  Future<void> setBlockfrostApiKey(String apiKey) async {}

  @override
  Future<void> deleteBlockfrostApiKey() async {}

  @override
  Future<List<String>> getEnabledAssets(String walletId) async => [];

  @override
  Future<void> setEnabledAssets(String walletId, List<String> units) async {}
}

void main() {
  group('WalletService current wallet', () {
    test('returns null when no wallets', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      final wallet = await service.getCurrentWallet();
      expect(wallet, isNull);
    });

    test(
      'returns first wallet and persists it when current id is unset',
      () async {
        final storage = FakeStorageService();
        final service = WalletService(storage);
        await service.addWallet(
          name: 'A',
          address: 'addr_test1abc',
          network: 'preview',
        );
        final wallet = await service.getCurrentWallet();
        expect(wallet, isNotNull);
        expect(wallet!.name, 'A');
        expect(await storage.getCurrentWalletId(), wallet.id);
      },
    );

    test('returns wallet matching persisted current id', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      await service.addWallet(
        name: 'A',
        address: 'addr_test1abc',
        network: 'preview',
      );
      await service.addWallet(
        name: 'B',
        address: 'addr_test1def',
        network: 'preview',
      );
      final wallets = await service.getWallets();
      final second = wallets[1];
      await service.setCurrentWallet(second.id);
      final current = await service.getCurrentWallet();
      expect(current!.name, 'B');
    });
  });
}
