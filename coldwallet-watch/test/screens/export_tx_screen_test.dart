import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/screens/export_tx_screen.dart';

ColdExport _createColdExport() {
  return ColdExport(
    version: 1,
    type: 'unsigned-tx',
    network: 'preview',
    txCbor:
        '84a60081825820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000181a200583900aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00021a00030d40031a00030d400a0f5f6',
    summary: TxSummary(
      fromAddress:
          'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
      toAddress:
          'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
      assets: [AssetAmount(unit: 'lovelace', quantity: '1000000')],
      fee: '200000',
    ),
  );
}

void main() {
  group('ExportTxScreen', () {
    testWidgets('only shows essential export info', (tester) async {
      final coldExport = _createColdExport();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/export-tx', arguments: coldExport);
              },
              child: const Text('Go'),
            ),
          ),
          routes: {'/export-tx': (context) => const ExportTxScreen()},
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // 交易详情（发送方、接收方、金额、手续费等）在 watch 端不需要显示，
      // 用户会在 coldwallet-app 签名时看到这些信息。
      expect(find.text('发送方'), findsNothing);
      expect(find.text('接收方'), findsNothing);
      expect(find.text('金额'), findsNothing);
      expect(find.text('手续费'), findsNothing);
      expect(find.text('网络'), findsNothing);

      // 只保留核心导出元素：二维码、JSON、复制按钮、下一步按钮。
      expect(find.text('二维码'), findsOneWidget);
      expect(find.text('JSON 文本'), findsOneWidget);
      expect(find.text('复制 JSON'), findsOneWidget);
      expect(find.text('下一步：导入签名结果'), findsOneWidget);
    });
  });
}
