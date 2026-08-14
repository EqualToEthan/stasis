/// 离线设备签名后导出给插件端的数据（已签名交易）
///
/// 包含签名后的完整交易 CBOR 和交易哈希，
/// 联网端导入后可直接提交到链上。
class ColdImport {
  final int version;
  final String type;
  final String txCbor;
  final String txHash;

  const ColdImport({
    required this.version,
    required this.type,
    required this.txCbor,
    required this.txHash,
  });

  factory ColdImport.fromJson(Map<String, dynamic> json) {
    return ColdImport(
      version: json['version'] as int,
      type: json['type'] as String,
      txCbor: json['txCbor'] as String,
      txHash: json['txHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'txCbor': txCbor,
      'txHash': txHash,
    };
  }
}
