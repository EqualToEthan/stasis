/// 热端导出给冷端的数据（未签名交易）
///
/// 包含交易 CBOR、网络标识和摘要信息，
/// 通过二维码或文件传递给冷钱包进行离线签名。
class ColdExport {
  final int version;
  final String type;
  final String network;
  final String txCbor;
  final TxSummary summary;

  const ColdExport({
    this.version = 1,
    this.type = 'unsigned-tx',
    required this.network,
    required this.txCbor,
    required this.summary,
  });

  factory ColdExport.fromJson(Map<String, dynamic> json) {
    return ColdExport(
      version: json['version'] as int? ?? 1,
      type: json['type'] as String? ?? 'unsigned-tx',
      network: json['network'] as String,
      txCbor: json['txCbor'] as String,
      summary: TxSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'network': network,
      'txCbor': txCbor,
      'summary': summary.toJson(),
    };
  }
}

/// 交易摘要，用于在冷钱包端展示交易关键信息
///
/// 包含发送方、接收方、资产列表和手续费，
/// 供用户在冷钱包上确认交易内容。
class TxSummary {
  final String fromAddress;
  final String toAddress;
  final List<AssetAmount> assets;
  final String fee;

  const TxSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.assets,
    required this.fee,
  });

  factory TxSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> assetsJson = json['assets'] as List<dynamic>;
    return TxSummary(
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      assets: assetsJson
          .map((e) => AssetAmount.fromJson(e as Map<String, dynamic>))
          .toList(),
      fee: json['fee'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'assets': assets.map((e) => e.toJson()).toList(),
      'fee': fee,
    };
  }
}

/// 交易中的单个资产及其数量
class AssetAmount {
  final String unit;
  final String quantity;
  final String? displayName;

  const AssetAmount({
    required this.unit,
    required this.quantity,
    this.displayName,
  });

  factory AssetAmount.fromJson(Map<String, dynamic> json) {
    return AssetAmount(
      unit: json['unit'] as String,
      quantity: json['quantity'] as String,
      displayName: json['displayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit': unit,
      'quantity': quantity,
      if (displayName != null) 'displayName': displayName,
    };
  }

  String get displayLabel => displayName ?? unit;
}
