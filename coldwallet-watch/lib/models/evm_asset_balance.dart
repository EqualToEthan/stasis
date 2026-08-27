/// EVM 资产余额模型
///
/// 表示某个 EVM 地址下一种资产的余额信息，支持原生代币（ETH、BNB 等）
/// 和 ERC-20 代币。数量以最小单位（wei）字符串保存，展示时按 [decimals] 格式化。
class EvmAssetBalance {
  /// ERC-20 合约地址；原生代币为 null。
  final String? contractAddress;

  /// 代币符号，如 ETH、USDT。
  final String symbol;

  /// 小数位，用于把 [balanceInWei] 格式化为可读金额。
  final int decimals;

  /// 以最小单位表示的余额字符串（wei）。
  final String balanceInWei;

  EvmAssetBalance({
    this.contractAddress,
    required this.symbol,
    required this.decimals,
    required this.balanceInWei,
  });

  /// 是否为原生代币
  bool get isNative => contractAddress == null;

  /// 把 [balanceInWei] 按 [decimals] 格式化为人类可读字符串。
  ///
  /// 例如 balanceInWei='1500000000000000000', decimals=18 → '1.5'。
  String get formattedBalance {
    final value = BigInt.parse(balanceInWei);
    if (decimals == 0) return value.toString();

    final divisor = BigInt.from(10).pow(decimals);
    final integerPart = value ~/ divisor;
    final remainder = value % divisor;
    final remainderStr = remainder.toString().padLeft(decimals, '0');
    final trimmed = remainderStr.replaceAll(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? integerPart.toString() : '$integerPart.$trimmed';
  }

  /// 从 JSON 反序列化
  factory EvmAssetBalance.fromJson(Map<String, dynamic> json) {
    return EvmAssetBalance(
      contractAddress: json['contractAddress'] as String?,
      symbol: json['symbol'] as String,
      decimals: json['decimals'] as int,
      balanceInWei: json['balanceInWei'] as String,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      if (contractAddress != null) 'contractAddress': contractAddress,
      'symbol': symbol,
      'decimals': decimals,
      'balanceInWei': balanceInWei,
    };
  }

  /// 创建副本并替换指定字段
  EvmAssetBalance copyWith({
    String? contractAddress,
    bool clearContractAddress = false,
    String? symbol,
    int? decimals,
    String? balanceInWei,
  }) {
    return EvmAssetBalance(
      contractAddress: clearContractAddress
          ? null
          : (contractAddress ?? this.contractAddress),
      symbol: symbol ?? this.symbol,
      decimals: decimals ?? this.decimals,
      balanceInWei: balanceInWei ?? this.balanceInWei,
    );
  }
}
