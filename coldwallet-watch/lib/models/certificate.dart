/// Cardano 质押证书类型
enum CertificateType { stakeRegistration, stakeDelegation, stakeDeregistration }

/// 质押证书模型（ColdExport 用）
///
/// 描述质押相关操作：注册、委托、解除注册。
/// 与 SDK 的 Certificate 类型对应，但仅用于 JSON 序列化传递给冷钱包。
class Certificate {
  final CertificateType type;

  /// blake2b_224(stake public key)，28 字节 hex 编码
  final String stakeCredential;

  /// 委托目标 pool key hash（仅 delegation 有值）
  final String? poolKeyHash;

  const Certificate({
    required this.type,
    required this.stakeCredential,
    this.poolKeyHash,
  });

  /// 序列化为 JSON，poolKeyHash 为 null 时省略
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'stakeCredential': stakeCredential,
    if (poolKeyHash != null) 'poolKeyHash': poolKeyHash,
  };

  /// 从 JSON 反序列化，未知 type 时抛出 [StateError]
  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      type: CertificateType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () =>
            throw StateError('Unknown certificate type: ${json['type']}'),
      ),
      stakeCredential: json['stakeCredential'] as String,
      poolKeyHash: json['poolKeyHash'] as String?,
    );
  }
}
