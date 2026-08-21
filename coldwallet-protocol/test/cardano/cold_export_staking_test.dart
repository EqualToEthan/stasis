import 'package:test/test.dart';
import 'package:coldwallet_protocol/coldwallet_protocol.dart';

void main() {
  group('ColdExport staking fields', () {
    test('payment transaction: staking fields and deposit default to null', () {
      final json = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '1000000'},
          ],
          'fee': '170000',
        },
      };
      final export = ColdExport.fromJson(json);

      expect(export.certificates, isNull);
      expect(export.withdrawals, isNull);
      expect(export.stakeKeyPath, isNull);
      expect(export.summary.deposit, isNull);
    });

    test('staking transaction: certificates parsed correctly', () {
      final json = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '2000000'},
          ],
          'fee': '180000',
        },
        'certificates': [
          {'type': 'stakeRegistration', 'stakeCredential': 'cred123'},
          {
            'type': 'stakeDelegation',
            'stakeCredential': 'cred123',
            'poolKeyHash': 'pool456',
          },
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(json);

      expect(export.certificates, hasLength(2));
      expect(export.certificates![0].type, CertificateType.stakeRegistration);
      expect(export.certificates![1].type, CertificateType.stakeDelegation);
      expect(export.certificates![1].poolKeyHash, 'pool456');
      expect(export.stakeKeyPath, "m/1852'/1815'/0'/2/0");
    });

    test('staking transaction: withdrawals parsed correctly', () {
      final json = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '0'},
          ],
          'fee': '175000',
        },
        'withdrawals': {'stake_test1abc': 5000000},
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(json);

      expect(export.withdrawals, {'stake_test1abc': 5000000});
    });

    test('toJson roundtrip preserves staking fields and deposit', () {
      final original = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '2000000'},
          ],
          'fee': '180000',
          'deposit': '2000000',
        },
        'certificates': [
          {
            'type': 'stakeDelegation',
            'stakeCredential': 'cred123',
            'poolKeyHash': 'pool456',
          },
        ],
        'withdrawals': {'stake_test1abc': 3000000},
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(original);
      final roundtripped = ColdExport.fromJson(export.toJson());

      expect(roundtripped.certificates, hasLength(1));
      expect(roundtripped.certificates![0].poolKeyHash, 'pool456');
      expect(roundtripped.withdrawals, {'stake_test1abc': 3000000});
      expect(roundtripped.stakeKeyPath, "m/1852'/1815'/0'/2/0");
      expect(roundtripped.summary.deposit, '2000000');
    });

    test('toJson roundtrip preserves negative deposit (deregistration)', () {
      final original = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '0'},
          ],
          'fee': '180000',
          'deposit': '-2000000',
        },
        'certificates': [
          {'type': 'stakeDeregistration', 'stakeCredential': 'cred123'},
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(original);
      final roundtripped = ColdExport.fromJson(export.toJson());

      expect(roundtripped.summary.deposit, '-2000000');
      expect(
        roundtripped.certificates![0].type,
        CertificateType.stakeDeregistration,
      );
    });

    test('toJson omits null staking fields and deposit', () {
      final json = {
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'assets': [
            {'unit': 'lovelace', 'quantity': '1000000'},
          ],
          'fee': '170000',
        },
      };
      final export = ColdExport.fromJson(json);
      final output = export.toJson();

      expect(output.containsKey('certificates'), isFalse);
      expect(output.containsKey('withdrawals'), isFalse);
      expect(output.containsKey('stakeKeyPath'), isFalse);
      final summaryOutput = output['summary'] as Map<String, dynamic>;
      expect(summaryOutput.containsKey('deposit'), isFalse);
    });
  });
}
