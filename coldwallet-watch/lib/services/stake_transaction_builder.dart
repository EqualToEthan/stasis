import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:hex/hex.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart'
    hide Certificate, CertificateType;
import 'package:coldwallet_protocol/cardano/certificate.dart' as proto_cert;
import 'blockfrost_service.dart';

/// 质押交易构建器
///
/// 构建 Cardano 质押相关的未签名交易：委托（注册+委托合并）、提取奖励、解除注册。
/// 所有方法返回 [ColdExport]，可导出给冷钱包签名。
class StakeTransactionBuilder {
  final BlockfrostService _blockfrost;

  /// Cardano stake key deposit（Conway era: 2 ADA = 2_000_000 lovelace）
  static const int stakeDepositLovelace = 2_000_000;

  StakeTransactionBuilder(this._blockfrost);

  /// 构建委托交易（自动注册 stake key + 委托给 pool）
  ///
  /// 如果 stake key 尚未注册，会同时包含 stakeRegistration 证书。
  /// [fromAddress] 支付地址（用于选择 UTxO 和找零）
  /// [stakeAddress] stake address（bech32 格式）
  /// [poolIdBech32] pool ID（bech32 格式，如 pool1abc...）
  /// [network] 网络标识（preview/mainnet）
  Future<ColdExport> buildDelegate({
    required String fromAddress,
    required String stakeAddress,
    required String poolIdBech32,
    required String network,
    required bool isStakeRegistered,
  }) async {
    final utxos = await _blockfrost.getAddressUtxos(fromAddress);
    if (utxos.isEmpty) throw Exception('地址没有可用的 UTxO');

    final latestBlock = await _blockfrost.getLatestBlock();
    final currentSlot = latestBlock['slot'] as int;
    final ttl = currentSlot + 3600;

    final params = await _blockfrost.getProtocolParams();
    final minFeeA = params['min_fee_a'] as int;
    final minFeeB = params['min_fee_b'] as int;

    // 提取 stake credential（28 字节）
    final stakeCredBytes = _extractStakeCredential(stakeAddress);
    final stakeCredential = Credential(CredType.ADDR_KEY_HASH, stakeCredBytes);
    final poolId = StakePoolId.fromBech32PoolId(poolIdBech32);

    // 构建证书列表
    final certs = <Certificate>[];
    if (!isStakeRegistered) {
      certs.add(
        Certificate.stakeRegistrationLegacy(stakeCredential: stakeCredential),
      );
    }
    certs.add(
      Certificate.stakeDelegation(
        stakeCredential: stakeCredential,
        stakePoolId: poolId,
      ),
    );

    // deposit 仅在注册时需要
    final deposit = isStakeRegistered
        ? BigInt.zero
        : BigInt.from(stakeDepositLovelace);

    return _buildStakingTx(
      fromAddress: fromAddress,
      utxos: utxos,
      ttl: ttl,
      minFeeA: minFeeA,
      minFeeB: minFeeB,
      network: network,
      certs: certs,
      withdrawals: null,
      extraCost: deposit,
      deposit: isStakeRegistered ? null : stakeDepositLovelace.toString(),
      exportCerts: [
        if (!isStakeRegistered)
          proto_cert.Certificate(
            type: proto_cert.CertificateType.stakeRegistration,
            stakeCredential: HEX.encode(stakeCredBytes),
          ),
        proto_cert.Certificate(
          type: proto_cert.CertificateType.stakeDelegation,
          stakeCredential: HEX.encode(stakeCredBytes),
          poolKeyHash: poolIdBech32,
        ),
      ],
    );
  }

  /// 构建提取奖励交易
  ///
  /// [fromAddress] 支付地址（用于 UTxO 和手续费）
  /// [stakeAddress] stake address（bech32 格式）
  /// [withdrawableAmount] 可提取的 lovelace 数量
  Future<ColdExport> buildWithdrawReward({
    required String fromAddress,
    required String stakeAddress,
    required BigInt withdrawableAmount,
    required String network,
  }) async {
    if (withdrawableAmount <= BigInt.zero) {
      throw Exception('无可提取的奖励');
    }

    final utxos = await _blockfrost.getAddressUtxos(fromAddress);
    if (utxos.isEmpty) throw Exception('地址没有可用的 UTxO');

    final latestBlock = await _blockfrost.getLatestBlock();
    final currentSlot = latestBlock['slot'] as int;
    final ttl = currentSlot + 3600;

    final params = await _blockfrost.getProtocolParams();
    final minFeeA = params['min_fee_a'] as int;
    final minFeeB = params['min_fee_b'] as int;

    return _buildStakingTx(
      fromAddress: fromAddress,
      utxos: utxos,
      ttl: ttl,
      minFeeA: minFeeA,
      minFeeB: minFeeB,
      network: network,
      certs: null,
      withdrawals: [Withdraw(stakeAddress, withdrawableAmount)],
      extraCost: BigInt.zero,
      // 奖励提取后 ADA 回到支付地址，相当于"收入"
      extraIncome: withdrawableAmount,
      exportWithdrawals: {stakeAddress: withdrawableAmount.toInt()},
    );
  }

  /// 构建解除 stake key 注册交易
  ///
  /// 解除后可退回 2 ADA deposit。
  Future<ColdExport> buildDeregister({
    required String fromAddress,
    required String stakeAddress,
    required String network,
  }) async {
    final utxos = await _blockfrost.getAddressUtxos(fromAddress);
    if (utxos.isEmpty) throw Exception('地址没有可用的 UTxO');

    final latestBlock = await _blockfrost.getLatestBlock();
    final currentSlot = latestBlock['slot'] as int;
    final ttl = currentSlot + 3600;

    final params = await _blockfrost.getProtocolParams();
    final minFeeA = params['min_fee_a'] as int;
    final minFeeB = params['min_fee_b'] as int;

    final stakeCredBytes = _extractStakeCredential(stakeAddress);
    final stakeCredential = Credential(CredType.ADDR_KEY_HASH, stakeCredBytes);

    return _buildStakingTx(
      fromAddress: fromAddress,
      utxos: utxos,
      ttl: ttl,
      minFeeA: minFeeA,
      minFeeB: minFeeB,
      network: network,
      certs: [
        Certificate.stakeDeRegistrationLegacy(stakeCredential: stakeCredential),
      ],
      withdrawals: null,
      extraCost: BigInt.zero,
      // 退还 deposit 2 ADA
      extraIncome: BigInt.from(stakeDepositLovelace),
      // 负数 deposit 表示退还押金（冷钱包端显示「退回押金」）
      deposit: '-$stakeDepositLovelace',
      exportCerts: [
        proto_cert.Certificate(
          type: proto_cert.CertificateType.stakeDeregistration,
          stakeCredential: HEX.encode(stakeCredBytes),
        ),
      ],
    );
  }

  /// 从 bech32 stake address 中提取 28 字节 stake credential hash
  ///
  /// stake address 格式：header(1 byte) + credential(28 bytes)
  Uint8List _extractStakeCredential(String stakeAddressBech32) {
    final decoded = stakeAddressBech32.bech32Decode();
    // 跳过第一个 header 字节（0xe0=testnet, 0xe1=mainnet）
    return Uint8List.fromList(decoded.sublist(1));
  }

  /// 构建用于费用估算的 witness set
  ///
  /// Cardano 的手续费按交易整体字节数计算，包含 witness set。未签名交易在导出时
  /// 使用空 witness set，但签名后会追加 payment key witness，质押交易还会追加
  /// stake key witness。因此估算费用时必须用占位 witness 计入这部分大小。
  WitnessSet _estimatedWitnessSet({required bool hasStakeWitness}) {
    final witnesses = <WitnessVKey>[_dummyVKeyWitness()];
    if (hasStakeWitness) {
      witnesses.add(_dummyVKeyWitness());
    }
    return WitnessSet(
      ivkeyWitnesses: ListWithCborType(witnesses, CborLengthType.definite, []),
    );
  }

  /// 生成与真实 witness 等大小的占位 witness
  ///
  /// VKey witness 的 CBOR 编码长度为：32 字节公钥 + 64 字节签名 + CBOR 头开销。
  /// 全 0 字节与实际随机字节在 CBOR bytes 类型中长度相同，适合用于费用估算。
  WitnessVKey _dummyVKeyWitness() =>
      WitnessVKey(vkey: Uint8List(32), signature: Uint8List(64));

  /// 通用质押交易构建方法（含迭代手续费计算）
  Future<ColdExport> _buildStakingTx({
    required String fromAddress,
    required List<Map<String, dynamic>> utxos,
    required int ttl,
    required int minFeeA,
    required int minFeeB,
    required String network,
    List<Certificate>? certs,
    List<Withdraw>? withdrawals,
    required BigInt extraCost,
    BigInt? extraIncome,
    String? deposit,
    List<proto_cert.Certificate>? exportCerts,
    Map<String, int>? exportWithdrawals,
  }) async {
    final income = extraIncome ?? BigInt.zero;
    var fee = BigInt.from(200000);
    final selectedUtxos = <Map<String, dynamic>>[];
    BigInt selectedLovelace = BigInt.zero;

    for (final utxo in utxos) {
      selectedUtxos.add(utxo);
      final utxoAmount = (utxo['amount'] as List<dynamic>).firstWhere(
        (a) => a['unit'] == 'lovelace',
        orElse: () => {'quantity': '0'},
      );
      selectedLovelace += BigInt.parse(utxoAmount['quantity'] as String);
      // 需要覆盖：fee + deposit（如有）- 退款收入 + 最小 UTxO
      if (selectedLovelace + income >= fee + extraCost + BigInt.from(1000000)) {
        break;
      }
    }

    if (selectedLovelace + income < fee + extraCost + BigInt.from(1000000)) {
      throw Exception('余额不足（需覆盖手续费${extraCost > BigInt.zero ? "和押金" : ""}）');
    }

    final inputs = selectedUtxos.map((utxo) {
      return CardanoTransactionInput(
        transactionHash: TransactionHash.fromHex(utxo['tx_hash'] as String),
        index: utxo['output_index'] as int,
      );
    }).toList();

    final networkId = network == 'mainnet'
        ? NetworkId.mainnet
        : NetworkId.testnet;
    final fromAddr = Address.fromBase58OrBech32(fromAddress);

    final sdkCerts = certs != null
        ? Certificates(
            certificates: certs,
            cborTags: [],
            lengthType: CborLengthType.definite,
          )
        : null;

    for (var i = 0; i < 5; i++) {
      final change = selectedLovelace + income - fee - extraCost;

      final outputs = <CardanoTransactionOutput>[];
      if (change >= BigInt.from(1000000)) {
        outputs.add(
          CardanoTransactionOutput.postAlonzo(
            address: fromAddr,
            value: Value.v0(lovelace: CborInt(change)),
            outDatum: null,
            scriptRef: null,
            lengthType: CborLengthType.definite,
          ),
        );
      }

      final body = CardanoTransactionBody.create(
        inputs: CardanoTransactionInputs(data: inputs, cborTags: []),
        outputs: outputs,
        fee: CborInt(fee),
        ttl: CborInt(BigInt.from(ttl)),
        certs: sdkCerts,
        withdrawals: withdrawals,
        networkId: networkId,
      );

      // 费用估算必须包含最终签名后的 witness 大小：
      // - 所有交易都需要 1 个 payment key witness
      // - 有 certificates 或 withdrawals 时还需 1 个 stake key witness
      final feeTx = CardanoTransaction(
        body: body,
        witnessSet: _estimatedWitnessSet(
          hasStakeWitness: certs != null || withdrawals != null,
        ),
        isValidDi: true,
        auxiliaryData: null,
        overrideBodyMetadataHash: false,
      );

      final txBytes = feeTx.serializeAsBytes();
      final newFee = BigInt.from(minFeeA * txBytes.length + minFeeB);
      if (newFee == fee) {
        // 导出的未签名交易仍使用空 witness set
        final tx = CardanoTransaction(
          body: body,
          witnessSet: const WitnessSet(),
          isValidDi: true,
          auxiliaryData: null,
          overrideBodyMetadataHash: false,
        );
        return ColdExport(
          network: network,
          txCbor: tx.serializeHexString(),
          summary: TxSummary(
            fromAddress: fromAddress,
            toAddress: fromAddress, // 质押交易回到自身
            assets: [AssetAmount(unit: 'lovelace', quantity: '0')],
            fee: fee.toString(),
            deposit: deposit,
          ),
          certificates: exportCerts,
          withdrawals: exportWithdrawals,
          stakeKeyPath: "m/1852'/1815'/0'/2/0",
        );
      }
      fee = newFee;
    }

    throw Exception('无法收敛到稳定的手续费估算');
  }
}
