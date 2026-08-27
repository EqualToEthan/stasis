import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/about_screen.dart';
import 'package:coldwallet_watch/screens/network_api_settings_screen.dart';
import 'package:coldwallet_watch/screens/settings_screen.dart';
import 'package:coldwallet_watch/screens/token_management_screen.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import '../support/fake_storage_service.dart';

void main() {
  group('SettingsScreen category list', () {
    testWidgets('shows all setting categories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(storageService: FakeStorageService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('网络与 API'), findsOneWidget);
      expect(find.text('代币管理'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('navigates to NetworkApiSettingsScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(storageService: FakeStorageService())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('网络与 API'));
      await tester.pumpAndSettle();

      expect(find.byType(NetworkApiSettingsScreen), findsOneWidget);
    });

    testWidgets('navigates to TokenManagementScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(storageService: FakeStorageService())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('代币管理'));
      await tester.pumpAndSettle();

      expect(find.byType(TokenManagementScreen), findsOneWidget);
    });

    testWidgets('navigates to AboutScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(storageService: FakeStorageService())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsOneWidget);
    });
  });
}
