import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 二维码扫描组件
///
/// 封装 mobile_scanner，扫描成功后通过 [onScan] 回传原始字符串。
class QRScanner extends StatelessWidget {
  final ValueChanged<String> onScan;

  const QRScanner({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        if (barcodes.isEmpty) return;
        final value = barcodes.first.rawValue;
        if (value != null) {
          onScan(value);
        }
      },
    );
  }
}
