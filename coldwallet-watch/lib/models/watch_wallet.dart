/// 只读钱包模型
///
/// 热端保存的冷钱包观察地址，仅含公钥地址和元数据，
/// 不包含任何私钥或助记词信息。
class WatchWallet {
  static int _idCounter = 0;

  final String id;
  final String name;
  final String address;
  final String network;
  final DateTime createdAt;

  WatchWallet({
    required this.id,
    required this.name,
    required this.address,
    required this.network,
    required this.createdAt,
  });

  /// 创建新钱包，自动生成基于时间戳的唯一 ID
  factory WatchWallet.create({
    required String name,
    required String address,
    required String network,
  }) {
    final now = DateTime.now();
    final id =
        '${now.millisecondsSinceEpoch}_${now.microsecond}_${_idCounter++}';
    return WatchWallet(
      id: id,
      name: name,
      address: address,
      network: network,
      createdAt: now,
    );
  }

  /// 从 JSON 反序列化
  factory WatchWallet.fromJson(Map<String, dynamic> json) {
    return WatchWallet(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      network: json['network'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'network': network,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 创建副本并替换指定字段
  WatchWallet copyWith({
    String? id,
    String? name,
    String? address,
    String? network,
    DateTime? createdAt,
  }) {
    return WatchWallet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      network: network ?? this.network,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
