import 'sign_result.dart';

/// EVM 链已签名交易（冷端 → 联网端）
///
/// 包含签名后的完整 RLP 交易 hex 和交易哈希，
/// 联网端导入后可直接提交到链上。
class EthColdImport {
  final int version;
  final String type;
  final String rawTxHex;
  final String txHash;

  const EthColdImport({
    required this.version,
    required this.type,
    required this.rawTxHex,
    required this.txHash,
  });

  factory EthColdImport.fromJson(Map<String, dynamic> json) {
    return EthColdImport(
      version: json['version'] as int,
      type: json['type'] as String,
      rawTxHex: json['rawTxHex'] as String,
      txHash: json['txHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'rawTxHex': rawTxHex,
      'txHash': txHash,
    };
  }

  /// 从 SignResult 构造
  factory EthColdImport.fromSignResult(SignResult result) {
    return EthColdImport(
      version: result.version,
      type: 'signed-tx',
      rawTxHex: result.signedTxHex,
      txHash: result.txHash,
    );
  }
}
