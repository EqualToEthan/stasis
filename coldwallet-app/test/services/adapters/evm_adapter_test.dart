import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/chain_config.dart';
import 'package:coldwallet_app/services/adapters/evm_adapter.dart';

void main() {
  group('EvmAdapter', () {
    late EvmAdapter adapter;
    late ChainConfig config;

    setUp(() {
      adapter = EvmAdapter();
      config = const ChainConfig(
        chainId: 'evm-11155111',
        chainFamily: 'evm',
        name: 'Ethereum Sepolia',
        network: 'sepolia',
        evmChainId: 11155111,
      );
    });

    test('chainFamily is evm', () {
      expect(adapter.chainFamily, 'evm');
    });

    test('parseExport parses valid EthColdExport JSON', () {
      final jsonStr =
          '{"version":1,"type":"unsigned-tx",'
          '"chainId":"evm-11155111","rawTxHex":"0xaabb",'
          '"summary":{"fromAddress":"0x1234","toAddress":"0x5678",'
          '"value":"1000","fee":"21000","nonce":1}}';
      final export = adapter.parseExport(jsonStr);
      expect(export.chainId, 'evm-11155111');
      expect(export.summary.fromAddress, '0x1234');
      expect(export.summary.nonce, 1);
    });

    test(
      'deriveAddress returns known address from known mnemonic',
      () async {
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about';
        final address = await adapter.deriveAddress(mnemonic, config);
        expect(address, startsWith('0x'));
        expect(address.length, 42);
        expect(
          address.toLowerCase(),
          '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
