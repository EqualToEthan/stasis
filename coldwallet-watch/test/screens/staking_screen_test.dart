import 'dart:math';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/export_tx_screen.dart';
import 'package:coldwallet_watch/screens/staking_screen.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';

Uint8List _randomBytes(int length) {
  final random = Random(42);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

String _testnetPaymentAddress(Uint8List paymentCred, Uint8List stakeCred) {
  final bytes = Uint8List(57)
    ..[0] =
        0x00 // base address, key/key, testnet
    ..setRange(1, 29, paymentCred)
    ..setRange(29, 57, stakeCred);
  return bytes.bech32Encode('addr_test');
}

String _testnetStakeAddress(Uint8List stakeCred) {
  final bytes = Uint8List(29)
    ..[0] =
        0xe0 // reward address, key, testnet
    ..setRange(1, 29, stakeCred);
  return bytes.bech32Encode('stake_test');
}

/// 用于 widget 测试的简易路由观察者，记录已 push 的路由名。
class _RouteObserver extends NavigatorObserver {
  final List<String> pushedRouteNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushedRouteNames.add(name);
    super.didPush(route, previousRoute);
  }
}

/// 模拟已委托 Pool 但未委托 DRep 的 Blockfrost 响应。
class _MockBlockfrostDelegated extends BlockfrostService {
  _MockBlockfrostDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {
        'active': true,
        'pool_id': 'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        'drep_id': null,
        'withdrawable_amount': '0',
      };
}

/// 模拟未委托（未注册）的 Blockfrost 响应。
class _MockBlockfrostNotDelegated extends BlockfrostService {
  _MockBlockfrostNotDelegated() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {'active': false, 'drep_id': null, 'withdrawable_amount': '0'};
}

/// 模拟已委托 Pool 但未委托 DRep，并有可提取奖励；同时提供构建交易所需数据。
class _MockBlockfrostNoDRepWithReward extends BlockfrostService {
  _MockBlockfrostNoDRepWithReward() : super(apiKey: 'test', network: 'preview');

  @override
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async =>
      {
        'active': true,
        'pool_id': 'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        'drep_id': null,
        'withdrawable_amount': '63804',
      };

  @override
  Future<List<Map<String, dynamic>>> getAddressUtxos(String address) async => [
    {
      'tx_hash':
          '24f74711cb06cdd980eca9882bbc5f551c2f4dba3e339a33bf61bd96e29cf10a',
      'output_index': 0,
      'amount': [
        {'unit': 'lovelace', 'quantity': '100000000'},
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> getLatestBlock() async => {'slot': 120000000};

  @override
  Future<Map<String, dynamic>> getProtocolParams() async => {
    'min_fee_a': 44,
    'min_fee_b': 155381,
  };
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
      'regression: hides pool id input and build button when already delegated',
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

        // 已质押时只显示当前质押信息，不提供输入框、更换按钮或构建按钮。
        expect(find.textContaining('当前质押池'), findsWidgets);
        expect(find.textContaining('解除当前质押'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('构建质押交易'), findsNothing);
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

      // 未质押时应显示 Pool ID 输入框。
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('构建质押交易'), findsOneWidget);
    });
  });

  group('StakingScreen withdraw panel', () {
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

    testWidgets('withdraw panel offers withdraw directly without DRep gate', (
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
            '/staking': (context) => StakingScreen(
              blockfrostService: _MockBlockfrostNoDRepWithReward(),
            ),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // 切换到提取奖励 tab
      await tester.tap(find.text('提取奖励'));
      await tester.pumpAndSettle();

      // 弃权随质押交易自动完成，不再有独立弃权入口；
      // 提取奖励按钮直接展示（奖励额度控制可用性）。
      expect(find.text('委托 DRep（弃权）'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('提取奖励'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('navigates to export-tx when withdraw pressed', (tester) async {
      // 构建交易需要有效的 bech32 地址，此处生成确定性的测试网地址。
      final paymentCred = _randomBytes(28);
      final stakeCred = _randomBytes(28);
      final validWallet = WatchWallet.create(
        name: 'Valid Wallet',
        address: _testnetPaymentAddress(paymentCred, stakeCred),
        stakeAddress: _testnetStakeAddress(stakeCred),
        chainFamily: 'cardano',
        network: 'preview',
      );

      ColdExport? capturedExport;
      final observer = _RouteObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/staking', arguments: validWallet);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {
            '/staking': (context) => StakingScreen(
              blockfrostService: _MockBlockfrostNoDRepWithReward(),
            ),
            '/export-tx': (context) => Builder(
              builder: (context) {
                capturedExport =
                    ModalRoute.of(context)?.settings.arguments as ColdExport?;
                return const ExportTxScreen();
              },
            ),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('提取奖励'));
      await tester.pumpAndSettle();

      // 弃权前置条件由质押交易自动满足，不再拦截提取奖励。
      final withdrawButton = find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('提取奖励'),
      );
      await tester.ensureVisible(withdrawButton);
      await tester.tap(withdrawButton);
      await tester.pumpAndSettle();

      // 如果构建失败，会通过 SnackBar 报错；先诊断是否有错误提示。
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        final snackBarText = find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(Text),
        );
        final texts = snackBarText.evaluate().map(
          (e) => (e.widget as Text).data,
        );
        fail('Unexpected SnackBar error: $texts');
      }

      expect(observer.pushedRouteNames, contains('/export-tx'));
      expect(find.text('二维码'), findsOneWidget);
      expect(capturedExport, isNotNull);
      // 提取奖励交易是纯 withdrawal，无证书
      expect(capturedExport?.withdrawals, isNotNull);
      expect(capturedExport?.certificates, isNull);
    });
  });
}
