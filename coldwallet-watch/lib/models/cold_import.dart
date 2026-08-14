/// 冷端签名后导出给热端的数据（已签名交易）
///
/// 包含签名后的完整交易 CBOR 和交易哈希，
/// 热钱包端导入后可直接提交到链上。
class ColdImport {
  final int version;
  final String type;
  final String txCbor;
  final String txHash;

  const ColdImport({
    this.version = 1,
    this.type = 'signed-tx',
    required this.txCbor,
    required this.txHash,
  });

  factory ColdImport.fromJson(Map<String, dynamic> json) {
    return ColdImport(
      version: json['version'] as int? ?? 1,
      type: json['type'] as String? ?? 'signed-tx',
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
