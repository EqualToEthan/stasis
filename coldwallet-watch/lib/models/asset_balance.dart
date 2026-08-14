/// 资产余额模型
///
/// 表示某个地址下的一种资产（ADA 或原生代币）的余额信息，
/// 包含资产标识、数量、显示名称和是否启用状态。
class AssetBalance {
  /// 资产标识，ADA 为 'lovelace'，原生代币为 policyId + assetName 的 hex 字符串
  final String unit;

  /// 资产数量（以最小单位表示）
  final String quantity;

  /// 用户可见的显示名称，为空时使用 unit 截断显示
  final String? displayName;

  /// 用户是否启用该资产的显示
  final bool isEnabled;

  AssetBalance({
    required this.unit,
    required this.quantity,
    this.displayName,
    this.isEnabled = false,
  });

  /// 是否为 ADA（lovelace）
  bool get isAda => unit == 'lovelace';

  /// 从 JSON 反序列化
  factory AssetBalance.fromJson(Map<String, dynamic> json) {
    return AssetBalance(
      unit: json['unit'] as String,
      quantity: json['quantity'] as String,
      displayName: json['displayName'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'unit': unit,
      'quantity': quantity,
      'displayName': displayName,
      'isEnabled': isEnabled,
    };
  }

  /// 创建副本并替换指定字段
  AssetBalance copyWith({
    String? unit,
    String? quantity,
    String? displayName,
    bool? isEnabled,
  }) {
    return AssetBalance(
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      displayName: displayName ?? this.displayName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
