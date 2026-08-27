import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/receive_screen.dart';

void main() {
  bool originalMainnet = AppConfig.isMainnet;

  tearDown(() {
    AppConfig.isMainnet = originalMainnet;
  });

  group('ReceiveScreen network hint', () {
    testWidgets('shows Cardano Preview for testnet Cardano wallet', (
      tester,
    ) async {
      AppConfig.isMainnet = false;
      final wallet = WatchWallet.create(
        name: 'Cardano Wallet',
        address:
            'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
        chainFamily: 'cardano',
        network: 'preview',
      );

      await tester.pumpWidget(_buildApp(wallet));
      await tester.pumpAndSettle();

      expect(find.text('仅接收 Cardano Preview 网络的资产'), findsOneWidget);
    });

    testWidgets('shows Cardano Mainnet for mainnet Cardano wallet', (
      tester,
    ) async {
      AppConfig.isMainnet = true;
      final wallet = WatchWallet.create(
        name: 'Cardano Wallet',
        address:
            'addr1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
        chainFamily: 'cardano',
        network: 'mainnet',
      );

      await tester.pumpWidget(_buildApp(wallet));
      await tester.pumpAndSettle();

      expect(find.text('仅接收 Cardano Mainnet 网络的资产'), findsOneWidget);
    });

    testWidgets('shows BSC Testnet for testnet EVM wallet', (tester) async {
      AppConfig.isMainnet = false;
      final wallet = WatchWallet.create(
        name: 'BSC Wallet',
        address: '0x1234567890123456789012345678901234567890',
        chainFamily: 'evm',
        chainId: 'evm-97',
        network: 'testnet',
      );

      await tester.pumpWidget(_buildApp(wallet));
      await tester.pumpAndSettle();

      expect(find.text('仅接收 BSC Testnet 网络的资产'), findsOneWidget);
    });

    testWidgets('shows BSC for mainnet EVM wallet', (tester) async {
      AppConfig.isMainnet = true;
      final wallet = WatchWallet.create(
        name: 'BSC Wallet',
        address: '0x1234567890123456789012345678901234567890',
        chainFamily: 'evm',
        chainId: 'evm-56',
        network: 'mainnet',
      );

      await tester.pumpWidget(_buildApp(wallet));
      await tester.pumpAndSettle();

      expect(find.text('仅接收 BSC 网络的资产'), findsOneWidget);
    });
  });
}

/// 构建包含 ReceiveScreen 路由的测试应用，把 [wallet] 作为页面参数传入。
Widget _buildApp(WatchWallet wallet) {
  return MaterialApp(
    home: Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: RouteSettings(arguments: wallet),
          builder: (_) => const ReceiveScreen(),
        );
      },
    ),
  );
}
