import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 二维码显示组件
///
/// 封装 qr_flutter 的 QrImageView，提供统一的尺寸和背景色配置。
class QRDisplay extends StatelessWidget {
  final String data;
  final double size;

  const QRDisplay({super.key, required this.data, this.size = 250});

  @override
  Widget build(BuildContext context) {
    return QrImageView(data: data, size: size, backgroundColor: Colors.white);
  }
}
