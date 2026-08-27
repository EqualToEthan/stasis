import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/screens/manage_evm_tokens_screen.dart';
import 'package:coldwallet_watch/services/evm_rpc_service.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/fake_storage_service.dart';

/// 控制 ERC-20 可读性校验结果的 mock RPC 服务。
class _FakeEvmRpcService extends EvmRpcService {
  final Set<String> _readableContracts;

  _FakeEvmRpcService({Set<String> readableContracts = const {}})
    : _readableContracts = readableContracts,
      super(client: http.Client());

  @override
  Future<bool> isErc20Readable(String rpcUrl, String contractAddress) async =>
      _readableContracts.contains(contractAddress.toLowerCase());

  @override
  Future<int> getTokenDecimals(String rpcUrl, String contractAddress) async =>
      18;

  @override
  Future<String> getTokenSymbol(String rpcUrl, String contractAddress) async =>
      'SYM';
}

void main() {
  group('ManageEvmTokensScreen', () {
    setUp(() {
      // 默认选中第一个 EVM 链；测试数据使用 evm-56，因此切换到主网。
      AppConfig.isMainnet = true;
    });

    tearDown(() {
      AppConfig.isMainnet = false;
    });
    testWidgets('shows empty hint and chain selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ManageEvmTokensScreen(
            storageService: FakeStorageService(),
            rpcService: _FakeEvmRpcService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('管理 EVM 代币'), findsOneWidget);
      expect(find.text('该链尚未添加任何 ERC-20 代币'), findsOneWidget);
    });

    testWidgets('validates and adds a token contract', (tester) async {
      final storage = FakeStorageService();
      final rpc = _FakeEvmRpcService(
        readableContracts: {'0xdac17f958d2ee523a2206206994597c13d831ec7'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ManageEvmTokensScreen(storageService: storage, rpcService: rpc),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      );
      await tester.tap(find.text('添加并校验'));
      await tester.pumpAndSettle();

      expect(
        find.text('0xdac17f958d2ee523a2206206994597c13d831ec7'),
        findsOneWidget,
      );
    });

    testWidgets('rejects invalid address format', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ManageEvmTokensScreen(
            storageService: FakeStorageService(),
            rpcService: _FakeEvmRpcService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'not-an-address');
      await tester.tap(find.text('添加并校验'));
      await tester.pumpAndSettle();

      expect(find.text('地址格式应为 0x 前缀的 40 位 hex'), findsOneWidget);
    });

    testWidgets('deletes a token contract', (tester) async {
      final storage = FakeStorageService(
        evmTokenContracts: {
          'evm-56': ['0xdac17f958d2ee523a2206206994597c13d831ec7'],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ManageEvmTokensScreen(
            storageService: storage,
            rpcService: _FakeEvmRpcService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(
        find.text('0xdac17f958d2ee523a2206206994597c13d831ec7'),
        findsNothing,
      );
      expect(find.text('该链尚未添加任何 ERC-20 代币'), findsOneWidget);
    });

    testWidgets('hides chain selector when initialChainId is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ManageEvmTokensScreen(
            storageService: FakeStorageService(),
            rpcService: _FakeEvmRpcService(),
            initialChainId: 'evm-97',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('选择链'), findsNothing);
      expect(find.text('该链尚未添加任何 ERC-20 代币'), findsOneWidget);
    });
  });
}
