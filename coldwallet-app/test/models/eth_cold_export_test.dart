import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/eth_cold_export.dart';

void main() {
  group('EthColdExport', () {
    final sampleJson = {
      'version': 1,
      'type': 'unsigned-tx',
      'chainId': 'evm-11155111',
      'rawTxHex': '0xabcdef',
      'summary': {
        'fromAddress': '0x1234',
        'toAddress': '0x5678',
        'value': '1000000000000000000',
        'fee': '21000000000000',
        'nonce': 42,
      },
    };

    test('fromJson parses correctly', () {
      final export = EthColdExport.fromJson(sampleJson);
      expect(export.version, 1);
      expect(export.type, 'unsigned-tx');
      expect(export.chainId, 'evm-11155111');
      expect(export.rawTxHex, '0xabcdef');
      expect(export.summary.fromAddress, '0x1234');
      expect(export.summary.toAddress, '0x5678');
      expect(export.summary.value, '1000000000000000000');
      expect(export.summary.fee, '21000000000000');
      expect(export.summary.nonce, 42);
    });

    test('toJson roundtrip', () {
      final export = EthColdExport.fromJson(sampleJson);
      final json = export.toJson();
      final restored = EthColdExport.fromJson(json);
      expect(restored.chainId, export.chainId);
      expect(restored.rawTxHex, export.rawTxHex);
      expect(restored.summary.nonce, export.summary.nonce);
    });
  });
}
