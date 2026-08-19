import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/wallet_service.dart';

void main() {
  group('WalletService.deriveStakeAddress', () {
    // 标准 BIP-39 测试向量（12 词），与 evm_adapter_test 共用
    const testMnemonic =
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';

    test('returns stake address starting with stake_test for testnet', () async {
      final service = WalletService();
      final stakeAddress =
          await service.deriveStakeAddress(testMnemonic, testnet: true);

      expect(stakeAddress, startsWith('stake_test'));
      expect(stakeAddress.length, greaterThan(40));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns stake address starting with stake for mainnet', () async {
      final service = WalletService();
      final stakeAddress =
          await service.deriveStakeAddress(testMnemonic, testnet: false);

      expect(stakeAddress, startsWith('stake1'));
      expect(stakeAddress, isNot(startsWith('stake_test')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('deterministic: same mnemonic produces same stake address', () async {
      final service = WalletService();
      final addr1 = await service.deriveStakeAddress(testMnemonic);
      final addr2 = await service.deriveStakeAddress(testMnemonic);

      expect(addr1, addr2);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('different mnemonic produces different stake address', () async {
      final service = WalletService();
      // 使用 generateMnemonic 保证生成有效的 BIP-39 助记词
      final otherMnemonic = service.generateMnemonic().join(' ');
      final addr1 = await service.deriveStakeAddress(testMnemonic);
      final addr2 = await service.deriveStakeAddress(otherMnemonic);

      expect(addr1, isNot(addr2));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
