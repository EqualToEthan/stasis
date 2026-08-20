import 'package:cardano_dart_types/cardano_dart_types.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'blockfrost_service.dart';

class TxBuilderService {
  final BlockfrostService _blockfrost;

  TxBuilderService(this._blockfrost);

  /// 构建 ADA 转账的未签名交易（MVP：仅支持 lovelace）。
  Future<ColdExport> buildTransferTx({
    required String fromAddress,
    required String toAddress,
    required List<AssetAmount> assets,
    required String network,
  }) async {
    if (assets.length != 1 || assets.first.unit != 'lovelace') {
      throw UnsupportedError('MVP 仅支持 ADA（lovelace）转账');
    }
    final amount = BigInt.parse(assets.first.quantity);

    final utxos = await _blockfrost.getAddressUtxos(fromAddress);
    if (utxos.isEmpty) {
      throw Exception('地址没有可用的 UTxO');
    }

    final latestBlock = await _blockfrost.getLatestBlock();
    final currentSlot = latestBlock['slot'] as int;
    final ttl = currentSlot + 3600; // 1 小时有效期

    final params = await _blockfrost.getProtocolParams();
    final minFeeA = params['min_fee_a'] as int;
    final minFeeB = params['min_fee_b'] as int;
    final minUtxoValue = BigInt.parse(
      params['min_utxo'] as String? ?? '1000000',
    );

    // 初始费用估算，后续迭代调整。
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
      if (selectedLovelace >= amount + fee + minUtxoValue) {
        break;
      }
    }

    if (selectedLovelace < amount + fee + minUtxoValue) {
      throw Exception('余额不足（需覆盖转账金额、手续费和最小 UTxO）');
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
    final toAddr = Address.fromBase58OrBech32(toAddress);

    // 迭代计算准确手续费。
    for (var i = 0; i < 5; i++) {
      final change = selectedLovelace - amount - fee;
      final outputs = _buildOutputs(
        toAddr: toAddr,
        amount: amount,
        fromAddr: fromAddr,
        change: change,
        minUtxoValue: minUtxoValue,
      );

      final body = CardanoTransactionBody.create(
        inputs: CardanoTransactionInputs(data: inputs, cborTags: []),
        outputs: outputs,
        fee: CborInt(fee),
        ttl: CborInt(BigInt.from(ttl)),
        networkId: networkId,
      );

      final tx = CardanoTransaction(
        body: body,
        witnessSet: const WitnessSet(),
        isValidDi: true,
        auxiliaryData: null,
        overrideBodyMetadataHash: false,
      );

      final txBytes = tx.serializeAsBytes();
      final newFee = BigInt.from(minFeeA * txBytes.length + minFeeB);
      if (newFee == fee) {
        return ColdExport(
          network: network,
          txCbor: tx.serializeHexString(),
          summary: TxSummary(
            fromAddress: fromAddress,
            toAddress: toAddress,
            assets: assets,
            fee: fee.toString(),
          ),
        );
      }
      fee = newFee;
    }

    throw Exception('无法收敛到稳定的手续费估算');
  }

  List<CardanoTransactionOutput> _buildOutputs({
    required Address toAddr,
    required BigInt amount,
    required Address fromAddr,
    required BigInt change,
    required BigInt minUtxoValue,
  }) {
    final outputs = <CardanoTransactionOutput>[
      CardanoTransactionOutput.postAlonzo(
        address: toAddr,
        value: Value.v0(lovelace: CborInt(amount)),
        outDatum: null,
        scriptRef: null,
        lengthType: CborLengthType.definite,
      ),
    ];

    if (change >= minUtxoValue) {
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

    return outputs;
  }
}
