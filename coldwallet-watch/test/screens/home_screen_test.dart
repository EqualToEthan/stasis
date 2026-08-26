import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/home_screen.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';
import 'package:coldwallet_watch/services/storage_service.dart';

/// 测试用的 StorageService 替身，避免调用真实的 SecureStorage/SharedPreferences。
class _FakeStorageService implements StorageService {
  final List<WatchWallet> _wallets;
  String? _apiKey;
  String? _currentWalletId;

  _FakeStorageService({
    required List<WatchWallet> wallets,
    String? apiKey,
    String? currentWalletId,
  }) : _wallets = wallets,
       _apiKey = apiKey,
       _currentWalletId = currentWalletId;

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
  Future<List<WatchWallet>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WatchWallet> wallets) async {}

  @override
  Future<String?> getCurrentWalletId() async => _currentWalletId;

  @override
  Future<void> setCurrentWalletId(String id) async {
    _currentWalletId = id;
  }

  @override
  Future<List<String>> getEnabledAssets(String walletId) async => [];

  @override
  Future<void> setEnabledAssets(String walletId, List<String> assets) async {}
}

/// 模拟 Blockfrost 余额响应，避免真实网络请求。
class _MockBlockfrost extends BlockfrostService {
  _MockBlockfrost() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getAddressBalance(String address) async => {
    'address': address,
    'amount': [
      {'unit': 'lovelace', 'quantity': '100000000'},
    ],
  };
}

void main() {
  group('HomeScreen action buttons', () {
    testWidgets(
      'shows staking and governance delegation buttons for Cardano wallet',
      (tester) async {
        final wallet = WatchWallet.create(
          name: 'Test Wallet',
          address:
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          stakeAddress:
              'stake_test1uz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqvqljap',
          chainFamily: 'cardano',
          network: 'preview',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              storageService: _FakeStorageService(
                wallets: [wallet],
                apiKey: 'test-api-key',
                currentWalletId: wallet.id,
              ),
              blockfrostService: _MockBlockfrost(),
            ),
          ),
        );
        // 等待异步加载完成；RefreshIndicator 在 pumpAndSettle 下可能超时，
        // 因此先 pump 固定时长再断言。
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('发送'), findsOneWidget);
        expect(find.text('收款'), findsOneWidget);
        expect(find.text('质押'), findsOneWidget);
        expect(find.text('治理委托'), findsOneWidget);
      },
    );

    testWidgets(
      'hides staking and governance delegation buttons for wallet without stake address',
      (tester) async {
        final wallet = WatchWallet.create(
          name: 'Test Wallet',
          address:
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          chainFamily: 'cardano',
          network: 'preview',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              storageService: _FakeStorageService(
                wallets: [wallet],
                apiKey: 'test-api-key',
                currentWalletId: wallet.id,
              ),
              blockfrostService: _MockBlockfrost(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('发送'), findsOneWidget);
        expect(find.text('收款'), findsOneWidget);
        expect(find.text('质押'), findsNothing);
        expect(find.text('治理委托'), findsNothing);
      },
    );
  });
}
