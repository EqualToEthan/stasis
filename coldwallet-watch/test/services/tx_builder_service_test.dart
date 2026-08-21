import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/services/blockfrost_service.dart';
import 'package:coldwallet_watch/services/tx_builder_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockBlockfrost extends BlockfrostService {
  _MockBlockfrost() : super(apiKey: 'test', network: 'preview');

  @override
  Future<List<Map<String, dynamic>>> getAddressUtxos(String address) async => [
    {
      'tx_hash':
          '24f74711cb06cdd980eca9882bbc5f551c2f4dba3e339a33bf61bd96e29cf10a',
      'output_index': 0,
      'amount': [
        {'unit': 'lovelace', 'quantity': '100000000'},
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> getLatestBlock() async => {'slot': 120000000};

  @override
  Future<Map<String, dynamic>> getProtocolParams() async => {
    'min_fee_a': 44,
    'min_fee_b': 155381,
    'min_utxo': '1000000',
  };
}

void main() {
  group('TxBuilderService', () {
    test('transfer fee covers payment witness size', () async {
      final builder = TxBuilderService(_MockBlockfrost());
      const fromAddress =
          'addr_test1qztcfsnmypgqcd9s97c5srwm45uqahgwas97jvrc4vxndahve82fu2n53z67lkpr8ycemx95my0h3llhesspmf6v0w8shgxz6l';
      final export = await builder.buildTransferTx(
        fromAddress: fromAddress,
        toAddress: fromAddress,
        assets: [AssetAmount(unit: 'lovelace', quantity: '1000000')],
        network: 'preview',
      );

      final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
      final signedTx = bodyTx.copyWithAdditionalSignatures(
        WitnessSet(
          ivkeyWitnesses: ListWithCborType(
            [WitnessVKey(vkey: Uint8List(32), signature: Uint8List(64))],
            CborLengthType.definite,
            [],
          ),
        ),
      );
      final signedBytes = signedTx.serializeAsBytes();
      const minFeeA = 44;
      const minFeeB = 155381;
      final requiredFee = minFeeA * signedBytes.length + minFeeB;

      expect(
        BigInt.parse(export.summary.fee),
        greaterThanOrEqualTo(BigInt.from(requiredFee)),
        reason: 'builder 估算的 fee 必须覆盖签名后交易大小（payment witness）',
      );
    });
  });
}
