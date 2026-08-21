import 'certificate.dart';

/// 观察钱包导出给冷钱包的数据（未签名交易）
///
/// 包含交易 CBOR、网络标识和摘要信息，
/// 通过二维码或文件传递给冷钱包进行离线签名。
/// 质押交易额外包含 [certificates]、[withdrawals]、[stakeKeyPath]。
class ColdExport {
  final int version;
  final String type;
  final String network;
  final String txCbor;
  final TxSummary summary;

  /// 质押证书列表（payment 交易时为 null）
  final List<Certificate>? certificates;

  /// 奖励提取：reward_address → lovelace 数量（payment 交易时为 null）
  final Map<String, int>? withdrawals;

  /// Stake key 派生路径（如 m/1852'/1815'/0'/2/0，payment 交易时为 null）
  final String? stakeKeyPath;

  const ColdExport({
    this.version = 1,
    this.type = 'unsigned-tx',
    required this.network,
    required this.txCbor,
    required this.summary,
    this.certificates,
    this.withdrawals,
    this.stakeKeyPath,
  });

  /// 从 JSON 反序列化，质押字段可选
  factory ColdExport.fromJson(Map<String, dynamic> json) {
    return ColdExport(
      version: json['version'] as int? ?? 1,
      type: json['type'] as String? ?? 'unsigned-tx',
      network: json['network'] as String,
      txCbor: json['txCbor'] as String,
      summary: TxSummary.fromJson(json['summary'] as Map<String, dynamic>),
      certificates: (json['certificates'] as List<dynamic>?)
          ?.map((e) => Certificate.fromJson(e as Map<String, dynamic>))
          .toList(),
      withdrawals: (json['withdrawals'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ),
      stakeKeyPath: json['stakeKeyPath'] as String?,
    );
  }

  /// 序列化为 JSON，质押字段为 null 时省略
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'network': network,
      'txCbor': txCbor,
      'summary': summary.toJson(),
      if (certificates != null)
        'certificates': certificates!.map((c) => c.toJson()).toList(),
      if (withdrawals != null) 'withdrawals': withdrawals,
      if (stakeKeyPath != null) 'stakeKeyPath': stakeKeyPath,
    };
  }
}

/// 交易摘要，供冷钱包用户确认交易内容
///
/// 包含发送方、接收方、资产列表、手续费和可选的质押押金。
/// [deposit] 仅在首次 stake registration 时为正数（lovelace 字符串），
/// 表示除手续费外还需锁定的 2 ADA 押金；其他情况为 null。
class TxSummary {
  final String fromAddress;
  final String toAddress;
  final List<AssetAmount> assets;
  final String fee;

  /// 质押押金（lovelace 字符串），首次注册时存在，否则为 null
  final String? deposit;

  const TxSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.assets,
    required this.fee,
    this.deposit,
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
      deposit: json['deposit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'assets': assets.map((e) => e.toJson()).toList(),
      'fee': fee,
      if (deposit != null) 'deposit': deposit,
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
