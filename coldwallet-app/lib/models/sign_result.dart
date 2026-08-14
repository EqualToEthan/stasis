/// 签名结果
///
/// 所有链的签名统一返回此结构，包含已签名交易的 hex 编码和交易哈希。
class SignResult {
  /// 已签名交易的 hex 编码（CBOR / RLP 等）
  final String signedTxHex;

  /// 交易哈希 hex
  final String txHash;

  /// 协议版本号
  final int version;

  const SignResult({
    required this.signedTxHex,
    required this.txHash,
    this.version = 1,
  });

  /// 转为通用的 JSON Map（用于 ColdImport 导出）
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': 'signed-tx',
      'rawTxHex': signedTxHex,
      'txHash': txHash,
    };
  }
}
