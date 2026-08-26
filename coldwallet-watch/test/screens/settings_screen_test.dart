import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/settings_screen.dart';
import 'package:coldwallet_watch/services/storage_service.dart';

/// 测试用的 StorageService 替身，避免调用真实的 SecureStorage/SharedPreferences。
class _FakeStorageService implements StorageService {
  String? _apiKey;

  @override
  Future<String?> getBlockfrostApiKey() async => _apiKey;

  @override
  Future<void> setBlockfrostApiKey(String apiKey) async {
    _apiKey = apiKey;
  }

  @override
  Future<void> deleteBlockfrostApiKey() async {
    _apiKey = null;
  }

  @override
  Future<List<WatchWallet>> loadWallets() async => [];

  @override
  Future<void> saveWallets(List<WatchWallet> wallets) async {}

  @override
  Future<String?> getCurrentWalletId() async => null;

  @override
  Future<void> setCurrentWalletId(String id) async {}

  @override
  Future<List<String>> getEnabledAssets(String walletId) async => [];

  @override
  Future<void> setEnabledAssets(String walletId, List<String> assets) async {}
}

void main() {
  group('SettingsScreen network display', () {
    tearDown(() {
      // 每个测试结束后恢复默认值，避免相互影响。
      AppConfig.isMainnet = false;
    });

    testWidgets('shows Preview testnet by default', (tester) async {
      AppConfig.isMainnet = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(storageService: _FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview 测试网'), findsOneWidget);
      expect(find.text('Mainnet 主网'), findsNothing);
      expect(
        find.text('全局网络开关控制，修改 AppConfig.isMainnet 后两端同步生效。'),
        findsOneWidget,
      );
    });

    testWidgets('shows Mainnet when AppConfig.isMainnet is true', (
      tester,
    ) async {
      AppConfig.isMainnet = true;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(storageService: _FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mainnet 主网'), findsOneWidget);
      expect(find.text('Preview 测试网'), findsNothing);
    });
  });
}
