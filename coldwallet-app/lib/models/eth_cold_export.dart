/// EVM 链未签名交易（联网端 → 冷端）
///
/// 包含 RLP 编码的未签名 EIP-1559 交易 hex、chainId 和摘要信息，
/// 通过二维码或文件传递给冷钱包进行离线签名。
class EthColdExport {
  final int version;
  final String type;
  final String chainId;
  final String rawTxHex;
  final EvmTxSummary summary;

  const EthColdExport({
    required this.version,
    required this.type,
    required this.chainId,
    required this.rawTxHex,
    required this.summary,
  });

  factory EthColdExport.fromJson(Map<String, dynamic> json) {
    return EthColdExport(
      version: json['version'] as int,
      type: json['type'] as String,
      chainId: json['chainId'] as String,
      rawTxHex: json['rawTxHex'] as String,
      summary: EvmTxSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'chainId': chainId,
      'rawTxHex': rawTxHex,
      'summary': summary.toJson(),
    };
  }
}

/// EVM 交易摘要
///
/// 包含发送方、接收方、金额、Gas 费用和 nonce，供冷端用户确认。
class EvmTxSummary {
  final String fromAddress;
  final String toAddress;
  final String value;
  final String fee;
  final int nonce;

  const EvmTxSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.value,
    required this.fee,
    required this.nonce,
  });

  factory EvmTxSummary.fromJson(Map<String, dynamic> json) {
    return EvmTxSummary(
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      value: json['value'] as String,
      fee: json['fee'] as String,
      nonce: json['nonce'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'value': value,
      'fee': fee,
      'nonce': nonce,
    };
  }
}
