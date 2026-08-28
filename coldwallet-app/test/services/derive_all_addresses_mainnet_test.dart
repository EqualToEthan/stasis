import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_app/services/wallet_service.dart';

// 标准 BIP-39 测试向量（12 词）
const testMnemonic =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

void main() {
  test(
    'WalletService.deriveAllAddresses includes cardano-mainnet and stake address in mainnet mode',
    () async {
      AppConfig.isMainnet = true;
      final walletService = WalletService();
      final addresses = await walletService.deriveAllAddresses(testMnemonic);

      expect(addresses.keys, contains('cardano-mainnet'));
      expect(addresses['cardano-mainnet'], startsWith('addr1'));

      final stakeAddress = await walletService.deriveStakeAddress(testMnemonic);
      expect(stakeAddress, startsWith('stake1'));
    },
  );
}
