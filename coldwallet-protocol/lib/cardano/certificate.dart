/// Cardano 质押/治理证书类型
///
/// 对应 Cardano transaction body 中的证书：
/// - [stakeRegistration] — 注册 stake key（需 2 ADA deposit）
/// - [stakeDelegation] — 委托给 stake pool
/// - [stakeDeregistration] — 解除 stake key 注册（退还 2 ADA deposit）
/// - [voteDelegation] — 把治理投票权委托给 DRep / 弃权 / 不信任（Conway 起）
enum CertificateType {
  stakeRegistration,
  stakeDelegation,
  stakeDeregistration,
  voteDelegation,
}

/// DRep 委托目标的类型
///
/// 本项目当前仅使用 [abstain]（弃权委托随质押委托交易自动附带），
/// 其余值为将来治理功能预留的协议扩展点。
enum DRepType { abstain, noConfidence, keyHash, scriptHash }

/// Cardano 质押/治理证书
///
/// 序列化后嵌入 [ColdExport] 的 `certificates` 字段，
/// 冷钱包端解析后生成对应 CBOR 证书并签名。
class Certificate {
  final CertificateType type;

  /// blake2b_224(stake public key)，28 字节 hex 编码
  final String stakeCredential;

  /// Pool key hash（28 字节 hex），仅 stakeDelegation 证书有值
  final String? poolKeyHash;

  /// DRep 委托目标类型，仅 voteDelegation 证书有值
  final DRepType? dRepType;

  /// DRep key/script hash（28 字节 hex），
  /// 仅 dRepType 为 keyHash / scriptHash 时有值
  final String? dRepHash;

  const Certificate({
    required this.type,
    required this.stakeCredential,
    this.poolKeyHash,
    this.dRepType,
    this.dRepHash,
  });

  /// 序列化为 JSON，可选字段为 null 时省略
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'stakeCredential': stakeCredential,
    if (poolKeyHash != null) 'poolKeyHash': poolKeyHash,
    if (dRepType != null) 'dRepType': dRepType!.name,
    if (dRepHash != null) 'dRepHash': dRepHash,
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
      dRepType: json['dRepType'] == null
          ? null
          : DRepType.values.firstWhere(
              (e) => e.name == json['dRepType'],
              orElse: () =>
                  throw StateError('Unknown DRep type: ${json['dRepType']}'),
            ),
      dRepHash: json['dRepHash'] as String?,
    );
  }
}
