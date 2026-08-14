import 'dart:convert';
import 'dart:math';

/// 钱包元数据（不含敏感信息）
///
/// 存储在 Secure Storage 的 `wallet_list` key 中，
/// 与助记词分离存储，助记词按 `wallet_{id}_mnemonic` 单独保存。
class WalletInfo {
  final String id;
  final String name;
  final DateTime createdAt;

  const WalletInfo({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory WalletInfo.create({required String name}) {
    return WalletInfo(id: _generateId(), name: name, createdAt: DateTime.now());
  }

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};
  }

  /// 生成 16 字符随机 ID（64 bits 足够 5 个钱包去重）
  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// 钱包列表 JSON 序列化/反序列化
class WalletListCodec {
  static String encode(List<WalletInfo> wallets) {
    return jsonEncode(wallets.map((w) => w.toJson()).toList());
  }

  static List<WalletInfo> decode(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => WalletInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
