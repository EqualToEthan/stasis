import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/evm_rpc_chain_list_screen.dart';
import 'package:coldwallet_watch/screens/network_api_settings_screen.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import '../support/fake_storage_service.dart';

void main() {
  group('NetworkApiSettingsScreen', () {
    tearDown(() {
      AppConfig.isMainnet = false;
    });

    testWidgets('shows Preview testnet by default', (tester) async {
      AppConfig.isMainnet = false;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkApiSettingsScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview 测试网'), findsOneWidget);
      expect(find.text('网络与 API'), findsOneWidget);
    });

    testWidgets('shows Mainnet when AppConfig.isMainnet is true', (
      tester,
    ) async {
      AppConfig.isMainnet = true;

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkApiSettingsScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mainnet 主网'), findsOneWidget);
    });

    testWidgets('saves Blockfrost API Key', (tester) async {
      final storage = FakeStorageService();
      await tester.pumpWidget(
        MaterialApp(home: NetworkApiSettingsScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'previewTestKey123');
      await tester.tap(find.text('保存 API Key'));
      await tester.pumpAndSettle();

      expect(find.text('API Key 已保存'), findsOneWidget);
      expect(await storage.getBlockfrostApiKey(), 'previewTestKey123');
    });

    testWidgets('navigates to EvmRpcChainListScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkApiSettingsScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('EVM RPC 端点'));
      await tester.pumpAndSettle();

      expect(find.byType(EvmRpcChainListScreen), findsOneWidget);
    });
  });
}
