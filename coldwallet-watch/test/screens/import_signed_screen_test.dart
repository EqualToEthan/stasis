import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/screens/import_signed_screen.dart';
import 'package:coldwallet_watch/widgets/qr_scanner.dart';

void main() {
  group('ImportSignedScreen', () {
    testWidgets(
      'regression: shows method selector instead of camera on first entry',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ImportSignedScreen()));

        // 进入页面后不应直接打开摄像头，而应显示两种导入方式供选择。
        expect(find.byType(QRScanner), findsNothing);
        expect(find.text('扫描二维码'), findsOneWidget);
        expect(find.text('粘贴 JSON'), findsOneWidget);
      },
    );

    testWidgets(
      'regression: paste JSON shows confirmation dialog before submitting',
      (tester) async {
        const testJson =
            '{"version":1,"type":"signed-tx","txCbor":"aabbccdd","txHash":"abcdef123456"}';

        // Mock clipboard to return test JSON
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': testJson};
            }
            return null;
          },
        );

        await tester.pumpWidget(const MaterialApp(home: ImportSignedScreen()));

        await tester.tap(find.text('粘贴 JSON'));
        // Use pump instead of pumpAndSettle to avoid getting stuck on
        // CircularProgressIndicator's infinite animation if _submit is reached.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Should show a confirmation dialog before submitting to chain.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      },
    );

    testWidgets('tapping qr option shows scanner and back returns selector', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ImportSignedScreen()));

      await tester.tap(find.text('扫描二维码'));
      await tester.pumpAndSettle();

      expect(find.byType(QRScanner), findsOneWidget);
      expect(find.text('选择其他方式'), findsOneWidget);

      await tester.tap(find.text('选择其他方式'));
      await tester.pumpAndSettle();

      expect(find.byType(QRScanner), findsNothing);
      expect(find.text('扫描二维码'), findsOneWidget);
      expect(find.text('粘贴 JSON'), findsOneWidget);
    });
  });
}
