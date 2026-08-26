import 'package:test/test.dart';
import 'package:coldwallet_protocol/coldwallet_protocol.dart';

void main() {
  group('Certificate', () {
    test('stakeRegistration toJson/fromJson roundtrip', () {
      const cert = Certificate(
        type: CertificateType.stakeRegistration,
        stakeCredential: 'abc123def456',
      );
      final json = cert.toJson();
      final restored = Certificate.fromJson(json);

      expect(restored.type, CertificateType.stakeRegistration);
      expect(restored.stakeCredential, 'abc123def456');
      expect(restored.poolKeyHash, isNull);
      // toJson should not include poolKeyHash when null
      expect(json.containsKey('poolKeyHash'), isFalse);
    });

    test('stakeDelegation toJson includes poolKeyHash', () {
      const cert = Certificate(
        type: CertificateType.stakeDelegation,
        stakeCredential: 'abc123',
        poolKeyHash: 'pool1hash456',
      );
      final json = cert.toJson();

      expect(json['type'], 'stakeDelegation');
      expect(json['stakeCredential'], 'abc123');
      expect(json['poolKeyHash'], 'pool1hash456');

      final restored = Certificate.fromJson(json);
      expect(restored.type, CertificateType.stakeDelegation);
      expect(restored.poolKeyHash, 'pool1hash456');
    });

    test('stakeDeregistration roundtrip', () {
      const cert = Certificate(
        type: CertificateType.stakeDeregistration,
        stakeCredential: 'xyz789',
      );
      final restored = Certificate.fromJson(cert.toJson());
      expect(restored.type, CertificateType.stakeDeregistration);
      expect(restored.stakeCredential, 'xyz789');
      expect(restored.poolKeyHash, isNull);
    });

    test('voteDelegation abstain toJson/fromJson roundtrip', () {
      const cert = Certificate(
        type: CertificateType.voteDelegation,
        stakeCredential: 'abc123def456',
        dRepType: DRepType.abstain,
      );
      final json = cert.toJson();
      final restored = Certificate.fromJson(json);

      expect(restored.type, CertificateType.voteDelegation);
      expect(restored.stakeCredential, 'abc123def456');
      expect(restored.dRepType, DRepType.abstain);
      expect(restored.dRepHash, isNull);
      // 可选字段为 null 时应省略，不污染 JSON
      expect(json.containsKey('poolKeyHash'), isFalse);
      expect(json.containsKey('dRepHash'), isFalse);
      expect(json['dRepType'], 'abstain');
    });

    test('voteDelegation keyHash roundtrip with dRepHash', () {
      const cert = Certificate(
        type: CertificateType.voteDelegation,
        stakeCredential: 'abc123',
        dRepType: DRepType.keyHash,
        dRepHash: 'd5b18fd6a48c0de1a2b3c4d5e6f70819',
      );
      final restored = Certificate.fromJson(cert.toJson());

      expect(restored.type, CertificateType.voteDelegation);
      expect(restored.dRepType, DRepType.keyHash);
      expect(restored.dRepHash, 'd5b18fd6a48c0de1a2b3c4d5e6f70819');
    });

    test('fromJson with unknown dRepType throws StateError', () {
      expect(
        () => Certificate.fromJson({
          'type': 'voteDelegation',
          'stakeCredential': 'x',
          'dRepType': 'unknown',
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('fromJson with unknown type throws StateError', () {
      expect(
        () => Certificate.fromJson({'type': 'unknown', 'stakeCredential': 'x'}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
