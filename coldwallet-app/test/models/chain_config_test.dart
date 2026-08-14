import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/chain_config.dart';

void main() {
  group('ChainConfig', () {
    test('constructs with required fields', () {
      const config = ChainConfig(
        chainId: 'evm-11155111',
        chainFamily: 'evm',
        name: 'Ethereum Sepolia',
        network: 'sepolia',
        evmChainId: 11155111,
      );
      expect(config.chainId, 'evm-11155111');
      expect(config.chainFamily, 'evm');
      expect(config.name, 'Ethereum Sepolia');
      expect(config.network, 'sepolia');
      expect(config.evmChainId, 11155111);
    });

    test('Cardano config has null evmChainId', () {
      const config = ChainConfig(
        chainId: 'cardano-preview',
        chainFamily: 'cardano',
        name: 'Cardano Preview',
        network: 'preview',
      );
      expect(config.evmChainId, isNull);
    });

    test('toJson and fromJson roundtrip', () {
      const config = ChainConfig(
        chainId: 'evm-97',
        chainFamily: 'evm',
        name: 'BSC Testnet',
        network: 'testnet',
        evmChainId: 97,
      );
      final json = config.toJson();
      final restored = ChainConfig.fromJson(json);
      expect(restored.chainId, config.chainId);
      expect(restored.chainFamily, config.chainFamily);
      expect(restored.evmChainId, config.evmChainId);
    });
  });
}
