import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/certificate.dart';
import 'package:coldwallet_app/models/cold_export.dart';
import 'package:coldwallet_app/services/adapters/cardano_adapter.dart';

void main() {
  group('CardanoAdapter staking', () {
    final adapter = CardanoAdapter();

    test('parseExport with no certificates: regular payment', () {
      final jsonString = '''
      {
        "version": 1,
        "type": "unsigned-tx",
        "network": "preview",
        "txCbor": "aabbccdd",
        "summary": {
          "fromAddress": "addr_test1qz",
          "toAddress": "addr_test1qz",
          "assets": [{"unit": "lovelace", "quantity": "1000000"}],
          "fee": "170000"
        }
      }
      ''';

      final export = adapter.parseExport(jsonString);
      expect(export.certificates, isNull);
      expect(export.withdrawals, isNull);
      expect(export.stakeKeyPath, isNull);
    });

    test('parseExport with certificates and stakeKeyPath: staking tx', () {
      final jsonString = '''
      {
        "version": 1,
        "type": "unsigned-tx",
        "network": "preview",
        "txCbor": "aabbccdd",
        "summary": {
          "fromAddress": "addr_test1qz",
          "toAddress": "addr_test1qz",
          "assets": [{"unit": "lovelace", "quantity": "2000000"}],
          "fee": "180000"
        },
        "certificates": [
          {"type": "stakeRegistration", "stakeCredential": "cred123"},
          {"type": "stakeDelegation", "stakeCredential": "cred123", "poolKeyHash": "pool1abc"}
        ],
        "stakeKeyPath": "m/1852'/1815'/0'/2/0"
      }
      ''';

      final export = adapter.parseExport(jsonString);
      expect(export.certificates, hasLength(2));
      expect(export.certificates![0].type, CertificateType.stakeRegistration);
      expect(export.certificates![1].type, CertificateType.stakeDelegation);
      expect(export.certificates![1].poolKeyHash, 'pool1abc');
      expect(export.stakeKeyPath, "m/1852'/1815'/0'/2/0");
    });

    test('parseExport with withdrawals: reward withdrawal', () {
      final jsonString = '''
      {
        "version": 1,
        "type": "unsigned-tx",
        "network": "preview",
        "txCbor": "aabbccdd",
        "summary": {
          "fromAddress": "addr_test1qz",
          "toAddress": "addr_test1qz",
          "assets": [{"unit": "lovelace", "quantity": "0"}],
          "fee": "170000"
        },
        "withdrawals": {"stake_test1rewardaddr": 5000000}
      }
      ''';

      final export = adapter.parseExport(jsonString);
      expect(export.withdrawals, isNotNull);
      expect(export.withdrawals!['stake_test1rewardaddr'], 5000000);
      expect(export.certificates, isNull);
    });

    test('parseExport with stakeDeregistration certificate', () {
      final jsonString = '''
      {
        "version": 1,
        "type": "unsigned-tx",
        "network": "preview",
        "txCbor": "aabbccdd",
        "summary": {
          "fromAddress": "addr_test1qz",
          "toAddress": "addr_test1qz",
          "assets": [{"unit": "lovelace", "quantity": "2000000"}],
          "fee": "170000"
        },
        "certificates": [
          {"type": "stakeDeregistration", "stakeCredential": "cred456"}
        ]
      }
      ''';

      final export = adapter.parseExport(jsonString);
      expect(export.certificates, hasLength(1));
      expect(export.certificates![0].type, CertificateType.stakeDeregistration);
      expect(export.certificates![0].poolKeyHash, isNull);
    });
  });
}
