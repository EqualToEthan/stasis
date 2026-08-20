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

    test('fromJson with unknown type throws StateError', () {
      expect(
        () => Certificate.fromJson({'type': 'unknown', 'stakeCredential': 'x'}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
