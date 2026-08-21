import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/staking_screen.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';

/// 模拟已委托的 Blockfrost 响应。
class _MockBlockfrostDelegated extends BlockfrostService {
  _MockBlockfrostDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {
        'active': true,
        'pool_id': 'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        'withdrawable_amount': '0',
      };
}

/// 模拟未委托（未注册）的 Blockfrost 响应。
class _MockBlockfrostNotDelegated extends BlockfrostService {
  _MockBlockfrostNotDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {'active': false, 'withdrawable_amount': '0'};
}

void main() {
  group('StakingScreen delegate panel', () {
    late WatchWallet wallet;

    setUp(() {
      wallet = WatchWallet.create(
        name: 'Test Wallet',
        address:
            'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
        stakeAddress:
            'stake_test1uz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqvqljap',
        chainFamily: 'cardano',
        network: 'preview',
      );
    });

    testWidgets(
      'regression: shows pool id input and current delegation when already delegated',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamed('/staking', arguments: wallet);
                },
                child: const Text('Go'),
              ),
            ),
            routes: {
              '/staking': (context) =>
                  StakingScreen(blockfrostService: _MockBlockfrostDelegated()),
            },
          ),
        );

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        // 已委托时仍应显示当前委托信息和 Pool ID 输入框，支持 re-delegation。
        expect(find.textContaining('已委托'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('构建委托交易'), findsOneWidget);
      },
    );

    testWidgets('shows pool id input when wallet is not delegated', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/staking', arguments: wallet);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {
            '/staking': (context) =>
                StakingScreen(blockfrostService: _MockBlockfrostNotDelegated()),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // 未委托时应显示 Pool ID 输入框。
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('构建委托交易'), findsOneWidget);
    });
  });
}
