import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/services/evm_rpc_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_storage_service.dart';

/// EvmRpcConfig 默认端点表回归测试。
///
/// 锁住 ADR-0008 的端点决策：
/// - 每条注册的 EVM 链必须有默认端点（新增链时防止漏配）
/// - BSC 不得回退到实测间歇挂死的 dataseed 端点（缺陷 D3）
void main() {
  group('EvmRpcConfig.defaultRpcUrls', () {
    test('every registered mainnet EVM chain has a default RPC', () {
      AppConfig.isMainnet = true;
      final evmChains = ChainRegistry.configsForFamily('evm');
      expect(evmChains.length, 4);
      for (final chain in evmChains) {
        expect(
          EvmRpcConfig.getDefaultRpcUrl(chain.chainId),
          isNotNull,
          reason: '${chain.chainId} 缺少默认 RPC 端点',
        );
      }
    });

    test('every registered testnet EVM chain has a default RPC', () {
      AppConfig.isMainnet = false;
      final evmChains = ChainRegistry.configsForFamily('evm');
      expect(evmChains.length, 4);
      for (final chain in evmChains) {
        expect(
          EvmRpcConfig.getDefaultRpcUrl(chain.chainId),
          isNotNull,
          reason: '${chain.chainId} 缺少默认 RPC 端点',
        );
      }
    });

    test('BSC endpoints use PublicNode instead of hanging dataseed', () {
      // dataseed 端点实测间歇挂死（ADR-0008 缺陷 D3），禁止回退
      expect(
        EvmRpcConfig.defaultRpcUrls['evm-56'],
        'https://bsc.publicnode.com',
      );
      expect(
        EvmRpcConfig.defaultRpcUrls['evm-97'],
        'https://bsc-testnet.publicnode.com',
      );
    });

    test('Ethereum mainnet and Sepolia endpoints are configured', () {
      expect(
        EvmRpcConfig.defaultRpcUrls['evm-1'],
        'https://ethereum-rpc.publicnode.com',
      );
      expect(
        EvmRpcConfig.defaultRpcUrls['evm-11155111'],
        'https://ethereum-sepolia-rpc.publicnode.com',
      );
    });

    tearDown(() {
      AppConfig.isMainnet = false;
    });
  });

  group('EvmRpcConfig.resolveRpcUrl', () {
    test('custom URL takes precedence over default', () async {
      final storage = FakeStorageService(
        evmRpcUrls: {'evm-56': 'https://my.rpc'},
      );
      final url = await EvmRpcConfig.resolveRpcUrl(storage, 'evm-56');
      expect(url, 'https://my.rpc');
    });

    test('falls back to default when custom is not set', () async {
      final storage = FakeStorageService();
      final url = await EvmRpcConfig.resolveRpcUrl(storage, 'evm-42161');
      expect(url, 'https://arb1.arbitrum.io/rpc');
    });

    test('throws StateError when neither custom nor default exists', () async {
      final storage = FakeStorageService();
      expect(
        () => EvmRpcConfig.resolveRpcUrl(storage, 'evm-unknown'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
