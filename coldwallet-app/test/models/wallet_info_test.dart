import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/wallet_info.dart';

void main() {
  group('WalletInfo', () {
    test('copyWith creates copy with new name', () {
      final wallet = WalletInfo.create(name: 'Original');
      final renamed = wallet.copyWith(name: 'Renamed');
      expect(renamed.id, wallet.id);
      expect(renamed.name, 'Renamed');
      expect(renamed.createdAt, wallet.createdAt);
    });

    test('copyWith preserves unspecified fields', () {
      final wallet = WalletInfo.create(name: 'Test');
      final copy = wallet.copyWith();
      expect(copy.id, wallet.id);
      expect(copy.name, wallet.name);
      expect(copy.createdAt, wallet.createdAt);
    });

    test('toJson and fromJson round trip preserves all fields', () {
      final wallet = WalletInfo.create(name: 'Round Trip');
      final json = wallet.toJson();
      final restored = WalletInfo.fromJson(json);
      expect(restored.id, wallet.id);
      expect(restored.name, wallet.name);
      expect(restored.createdAt, wallet.createdAt);
    });
  });
}
