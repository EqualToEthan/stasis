/// 只读钱包模型
///
/// 热端保存的冷钱包观察地址，仅含公钥地址和元数据，
/// 不包含任何私钥或助记词信息。
/// 支持多链：[chainFamily] 区分链族（cardano / evm），
/// EVM 链通过 [chainId] 进一步区分具体链。
class WatchWallet {
  static int _idCounter = 0;

  final String id;
  final String name;
  final String address;

  /// Cardano stake address（可选，仅 Cardano 链族有效）
  final String? stakeAddress;

  /// 链族标识：'cardano' 或 'evm'
  final String chainFamily;

  /// 具体链 ID（EVM 链需要，如 'sepolia'、'bsc-testnet'）
  final String? chainId;

  final String network;
  final DateTime createdAt;

  WatchWallet({
    required this.id,
    required this.name,
    required this.address,
    this.stakeAddress,
    required this.chainFamily,
    this.chainId,
    required this.network,
    required this.createdAt,
  });

  /// 创建新钱包，自动生成基于时间戳的唯一 ID
  factory WatchWallet.create({
    required String name,
    required String address,
    String? stakeAddress,
    required String chainFamily,
    String? chainId,
    required String network,
  }) {
    final now = DateTime.now();
    final id =
        '${now.millisecondsSinceEpoch}_${now.microsecond}_${_idCounter++}';
    return WatchWallet(
      id: id,
      name: name,
      address: address,
      stakeAddress: stakeAddress,
      chainFamily: chainFamily,
      chainId: chainId,
      network: network,
      createdAt: now,
    );
  }

  /// 从 JSON 反序列化
  ///
  /// 向后兼容：旧数据无 chainFamily 字段时默认为 'cardano'，
  /// 旧数据无 stakeAddress 字段时为 null。
  factory WatchWallet.fromJson(Map<String, dynamic> json) {
    return WatchWallet(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      stakeAddress: json['stakeAddress'] as String?,
      chainFamily: (json['chainFamily'] as String?) ?? 'cardano',
      chainId: json['chainId'] as String?,
      network: json['network'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 序列化为 JSON（可选字段为 null 时省略）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      if (stakeAddress != null) 'stakeAddress': stakeAddress,
      'chainFamily': chainFamily,
      if (chainId != null) 'chainId': chainId,
      'network': network,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 是否为 Cardano 链族
  bool get isCardano => chainFamily == 'cardano';

  /// 是否为 EVM 链族
  bool get isEvm => chainFamily == 'evm';

  /// 创建副本并替换指定字段
  WatchWallet copyWith({
    String? id,
    String? name,
    String? address,
    String? stakeAddress,
    bool clearStakeAddress = false,
    String? chainFamily,
    String? chainId,
    bool clearChainId = false,
    String? network,
    DateTime? createdAt,
  }) {
    return WatchWallet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      stakeAddress: clearStakeAddress
          ? null
          : (stakeAddress ?? this.stakeAddress),
      chainFamily: chainFamily ?? this.chainFamily,
      chainId: clearChainId ? null : (chainId ?? this.chainId),
      network: network ?? this.network,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
