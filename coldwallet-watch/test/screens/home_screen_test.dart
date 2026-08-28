import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/evm_asset_balance.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/home_screen.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';
import 'package:coldwallet_watch/services/evm_asset_service.dart';
import 'package:coldwallet_watch/services/evm_rpc_service.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import '../support/fake_storage_service.dart';

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

/// 返回预设 EVM 资产余额的 mock 服务。
class _FakeEvmAssetService extends EvmAssetService {
  final List<EvmAssetBalance> _balances;

  _FakeEvmAssetService(this._balances)
    : super(EvmRpcService(), FakeStorageService(wallets: []));

  @override
  Future<List<EvmAssetBalance>> loadBalances(
    String chainId,
    String address,
  ) async => _balances;
}

/// 始终抛异常的 mock 服务，用于测试单链查询失败的错误态。
class _FailingEvmAssetService extends EvmAssetService {
  int callCount = 0;

  _FailingEvmAssetService()
    : super(EvmRpcService(), FakeStorageService(wallets: []));

  @override
  Future<List<EvmAssetBalance>> loadBalances(
    String chainId,
    String address,
  ) async {
    callCount++;
    throw Exception('network down');
  }
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
              storageService: FakeStorageService(
                wallets: [wallet],
                blockfrostApiKey: 'test-api-key',
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
              storageService: FakeStorageService(
                wallets: [wallet],
                blockfrostApiKey: 'test-api-key',
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

    testWidgets('shows native balance and ERC-20 tokens for EVM wallet', (
      tester,
    ) async {
      final wallet = WatchWallet.create(
        name: 'EVM Wallet',
        address: '0xDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEf',
        chainFamily: 'evm',
        chainId: 'evm-56',
        network: 'mainnet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: FakeStorageService(
              wallets: [wallet],
              currentWalletId: wallet.id,
            ),
            evmAssetService: _FakeEvmAssetService([
              EvmAssetBalance(
                symbol: 'BNB',
                decimals: 18,
                balanceInWei: '2500000000000000000',
              ),
              EvmAssetBalance(
                contractAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
                symbol: 'USDT',
                decimals: 6,
                balanceInWei: '1000000',
              ),
            ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2.5 BNB'), findsOneWidget);
      expect(find.text('USDT'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('质押'), findsNothing);
      expect(find.text('治理委托'), findsNothing);
    });

    testWidgets('shows add token hint when EVM wallet has no ERC-20 tokens', (
      tester,
    ) async {
      final wallet = WatchWallet.create(
        name: 'EVM Wallet',
        address: '0xDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEf',
        chainFamily: 'evm',
        chainId: 'evm-56',
        network: 'mainnet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: FakeStorageService(
              wallets: [wallet],
              currentWalletId: wallet.id,
            ),
            evmAssetService: _FakeEvmAssetService([
              EvmAssetBalance(symbol: 'ETH', decimals: 18, balanceInWei: '0'),
            ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('暂无 ERC-20 代币，请到设置页添加'), findsOneWidget);
    });

    testWidgets('shows per-chain error state with retry when EVM query fails', (
      tester,
    ) async {
      final wallet = WatchWallet.create(
        name: 'EVM Wallet',
        address: '0xDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEf',
        chainFamily: 'evm',
        chainId: 'evm-56',
        network: 'mainnet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: FakeStorageService(
              wallets: [wallet],
              currentWalletId: wallet.id,
            ),
            evmAssetService: _FailingEvmAssetService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 错误态可见，与“余额为 0”可区分
      expect(find.text('该链查询失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('retry button re-triggers failed chain query', (tester) async {
      final wallet = WatchWallet.create(
        name: 'EVM Wallet',
        address: '0xDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEf',
        chainFamily: 'evm',
        chainId: 'evm-56',
        network: 'mainnet',
      );
      final service = _FailingEvmAssetService();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: FakeStorageService(
              wallets: [wallet],
              currentWalletId: wallet.id,
            ),
            evmAssetService: service,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final callsAfterFirstLoad = service.callCount;
      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(service.callCount, greaterThan(callsAfterFirstLoad));
    });
  });
}
