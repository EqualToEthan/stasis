import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/evm_rpc_chain_list_screen.dart';
import 'package:coldwallet_watch/screens/evm_rpc_edit_screen.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import '../support/fake_storage_service.dart';

void main() {
  group('EvmRpcChainListScreen', () {
    tearDown(() {
      AppConfig.isMainnet = false;
    });

    testWidgets('shows default RPC status for each chain', (tester) async {
      AppConfig.isMainnet = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EvmRpcChainListScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BSC Testnet'), findsOneWidget);
      expect(find.text('默认 RPC'), findsWidgets);
    });

    testWidgets('shows custom RPC summary', (tester) async {
      final storage = FakeStorageService();
      await storage.setEvmRpcUrl('evm-97', 'https://custom.bsc.rpc');

      await tester.pumpWidget(
        MaterialApp(home: EvmRpcChainListScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('自定义：https://custom.bsc.rpc'), findsOneWidget);
    });

    testWidgets('navigates to EvmRpcEditScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EvmRpcChainListScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('BSC Testnet'));
      await tester.pumpAndSettle();

      expect(find.byType(EvmRpcEditScreen), findsOneWidget);
      expect(find.text('BSC Testnet'), findsWidgets);
    });
  });

  group('EvmRpcEditScreen', () {
    tearDown(() {
      AppConfig.isMainnet = false;
    });

    testWidgets('saves custom RPC URL and pops', (tester) async {
      final storage = FakeStorageService();
      final chain = ChainRegistry.getConfig('evm-97')!;
      bool? poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EvmRpcEditScreen(chain: chain, storageService: storage),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://my.sepolia.rpc');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(poppedResult, isTrue);
      expect(await storage.getEvmRpcUrl('evm-97'), 'https://my.sepolia.rpc');
    });

    testWidgets('restore default clears the input', (tester) async {
      final storage = FakeStorageService();
      final chain = ChainRegistry.getConfig('evm-97')!;

      await tester.pumpWidget(
        MaterialApp(
          home: EvmRpcEditScreen(chain: chain, storageService: storage),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://tmp.rpc');
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pump();

      expect(find.text('https://tmp.rpc'), findsNothing);
    });
  });
}
