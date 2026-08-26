import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/governance_delegation_screen.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';

/// 模拟已质押 Pool 且 DRep 弃权随质押自动完成的 Blockfrost 响应。
class _MockBlockfrostAutoAbstain extends BlockfrostService {
  _MockBlockfrostAutoAbstain() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {
        'active': true,
        'pool_id': 'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        'drep_id': null,
        'withdrawable_amount': '0',
      };
}

/// 模拟已委托具体 DRep 的 Blockfrost 响应。
class _MockBlockfrostDRepDelegated extends BlockfrostService {
  _MockBlockfrostDRepDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(
    String stakeAddress,
  ) async => {
    'active': true,
    'pool_id': 'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
    'drep_id': 'drep1ygcz2r8fhsjv2rm6v8nxn8yn7py8nhq2ypzqgp6c6q8ayzqmm4pegz',
    'withdrawable_amount': '0',
  };
}

/// 模拟未质押也未设置 DRep 的 Blockfrost 响应。
class _MockBlockfrostNotDelegated extends BlockfrostService {
  _MockBlockfrostNotDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {'active': false, 'drep_id': null, 'withdrawable_amount': '0'};
}

void main() {
  group('GovernanceDelegationScreen status display', () {
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

    testWidgets('shows auto abstain status when pool is delegated', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/governance-delegation', arguments: wallet);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {
            '/governance-delegation': (context) => GovernanceDelegationScreen(
              blockfrostService: _MockBlockfrostAutoAbstain(),
            ),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('治理委托'), findsOneWidget);
      expect(find.text('已默认弃权'), findsOneWidget);
      expect(find.text('弃权（随质押自动完成）'), findsOneWidget);
      expect(
        find.text(
          '本应用当前仅支持默认弃权（abstain），即不参与治理投票。'
          '当你在「质押」页面完成首次 Stake Pool 质押时，系统会自动附带弃权证书，'
          '无需在此页面手动操作。',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows external DRep delegation status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/governance-delegation', arguments: wallet);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {
            '/governance-delegation': (context) => GovernanceDelegationScreen(
              blockfrostService: _MockBlockfrostDRepDelegated(),
            ),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('已委托'), findsOneWidget);
      expect(find.textContaining('已委托给外部 DRep'), findsOneWidget);
    });

    testWidgets('shows not set status when stake key is not registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/governance-delegation', arguments: wallet);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {
            '/governance-delegation': (context) => GovernanceDelegationScreen(
              blockfrostService: _MockBlockfrostNotDelegated(),
            ),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('未设置'), findsOneWidget);
      expect(find.text('尚未质押；完成首次质押后将自动弃权'), findsOneWidget);
    });
  });
}
