/// Cardano 质押证书类型
///
/// 对应 Cardano transaction body 中的三种证书：
/// - [stakeRegistration] — 注册 stake key（需 2 ADA deposit）
/// - [stakeDelegation] — 委托给 stake pool
/// - [stakeDeregistration] — 解除 stake key 注册（退还 2 ADA deposit）
enum CertificateType { stakeRegistration, stakeDelegation, stakeDeregistration }

/// Cardano 质押证书
///
/// 序列化后嵌入 [ColdExport] 的 `certificates` 字段，
/// 冷钱包端解析后生成对应 CBOR 证书并签名。
class Certificate {
  final CertificateType type;

  /// blake2b_224(stake public key)，28 字节 hex 编码
  final String stakeCredential;

  /// Pool key hash（28 字节 hex），仅 delegation 证书有值
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
