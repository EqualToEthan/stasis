import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/manage_evm_tokens_screen.dart';
import 'package:coldwallet_watch/screens/token_management_screen.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import '../support/fake_storage_service.dart';

void main() {
  group('TokenManagementScreen', () {
    tearDown(() {
      AppConfig.isMainnet = false;
    });

    testWidgets('shows EVM chain entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TokenManagementScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('代币管理'), findsOneWidget);
      expect(find.text('Ethereum Sepolia'), findsOneWidget);
    });

    testWidgets('navigates to ManageEvmTokensScreen with initial chain', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TokenManagementScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ethereum Sepolia'));
      await tester.pumpAndSettle();

      expect(find.byType(ManageEvmTokensScreen), findsOneWidget);
      expect(find.text('选择链'), findsNothing);
    });
  });
}
