/// 链配置
///
/// 描述一条链的基本信息，供 ChainAdapter 使用。
/// 所有配置在 ChainRegistry 中静态定义，不可运行时修改。
class ChainConfig {
  /// 唯一标识，如 "cardano-preview"、"evm-11155111"
  final String chainId;

  /// 链族标识："cardano"、"evm"、"bitcoin"
  final String chainFamily;

  /// 显示名称，如 "Cardano Preview"、"Ethereum Sepolia"
  final String name;

  /// 网络标识，如 "preview"、"sepolia"
  final String network;

  /// EVM 链专用链 ID（如 11155111、97），非 EVM 链为 null
  final int? evmChainId;

  const ChainConfig({
    required this.chainId,
    required this.chainFamily,
    required this.name,
    required this.network,
    this.evmChainId,
  });

  factory ChainConfig.fromJson(Map<String, dynamic> json) {
    return ChainConfig(
      chainId: json['chainId'] as String,
      chainFamily: json['chainFamily'] as String,
      name: json['name'] as String,
      network: json['network'] as String,
      evmChainId: json['evmChainId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chainId': chainId,
      'chainFamily': chainFamily,
      'name': name,
      'network': network,
      if (evmChainId != null) 'evmChainId': evmChainId,
    };
  }
}
