import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/chain_registry.dart';

void main() {
  // 每个测试前初始化为测试网，每个测试后重置回测试网
  setUp(() => AppConfig.isMainnet = false);
  tearDown(() => AppConfig.isMainnet = false);

  group('ChainRegistry.resolveChainId', () {
    test('returns cardano-preview when chainId field absent', () {
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });

    test('returns the chainId value when present', () {
      final json = <String, dynamic>{'chainId': 'evm-97'};
      expect(ChainRegistry.resolveChainId(json), 'evm-97');
    });

    test('returns cardano-preview when chainId is explicitly null', () {
      final json = <String, dynamic>{'chainId': null};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });

    test('does not crash on non-String chainId (defensive)', () {
      final json = <String, dynamic>{'chainId': 123};
      expect(ChainRegistry.resolveChainId(json), 'cardano-preview');
    });
  });

  group('ChainRegistry.getConfig', () {
    test('returns config for known cardano chain', () {
      final config = ChainRegistry.getConfig('cardano-preview');
      expect(config, isNotNull);
      expect(config!.chainFamily, 'cardano');
    });

    test('returns config for known evm chain', () {
      final config = ChainRegistry.getConfig('evm-97');
      expect(config, isNotNull);
      expect(config!.chainFamily, 'evm');
    });

    test('returns null for unknown chain', () {
      expect(ChainRegistry.getConfig('unknown-chain'), isNull);
    });
  });

  group('ChainRegistry auto-detection flow', () {
    test('JSON without chainId resolves to registered cardano chain', () {
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      final chainId = ChainRegistry.resolveChainId(json);
      expect(ChainRegistry.getConfig(chainId), isNotNull);
    });

    test('JSON with known EVM chainId resolves to registered chain', () {
      final json = <String, dynamic>{'chainId': 'evm-97'};
      final chainId = ChainRegistry.resolveChainId(json);
      expect(ChainRegistry.getConfig(chainId), isNotNull);
    });

    test('JSON with unknown chainId fails getConfig', () {
      final json = <String, dynamic>{'chainId': 'ethereum-mainnet'};
      final chainId = ChainRegistry.resolveChainId(json);
      expect(ChainRegistry.getConfig(chainId), isNull);
    });
  });

  group('ChainRegistry.mismatchMessage', () {
    test('returns null when chains match', () {
      expect(
        ChainRegistry.mismatchMessage('cardano-preview', 'cardano-preview'),
        isNull,
      );
    });

    test('returns message with friendly names on mismatch', () {
      final msg = ChainRegistry.mismatchMessage('evm-97', 'evm-421614');
      expect(msg, isNotNull);
      expect(msg!, contains('BSC Testnet'));
      expect(msg, contains('Arbitrum Sepolia'));
      expect(msg, contains('请切换链后重试'));
    });

    test('falls back to raw chainId when config not found', () {
      final msg = ChainRegistry.mismatchMessage('evm-97', 'unknown-chain');
      expect(msg, isNotNull);
      expect(msg!, contains('unknown-chain'));
    });

    test('cardano scanned (no chainId) matches selected cardano-preview', () {
      // 模拟扫码得到无 chainId 的 Cardano ColdExport
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      final scanned = ChainRegistry.resolveChainId(json);
      expect(ChainRegistry.mismatchMessage('cardano-preview', scanned), isNull);
    });

    test('cardano scanned does NOT match selected evm chain', () {
      final json = <String, dynamic>{'type': 'unsigned-tx'};
      final scanned = ChainRegistry.resolveChainId(json);
      final msg = ChainRegistry.mismatchMessage('evm-97', scanned);
      expect(msg, isNotNull);
      expect(msg!, contains('BSC Testnet'));
      expect(msg, contains('Cardano Preview'));
    });
  });

  group('ChainRegistry 配置组切换', () {
    test('默认测试网: resolveChainId 返回 cardano-preview', () {
      expect(ChainRegistry.resolveChainId({}), 'cardano-preview');
    });

    test('主网模式: resolveChainId 返回 cardano-mainnet', () {
      AppConfig.isMainnet = true;
      expect(ChainRegistry.resolveChainId({}), 'cardano-mainnet');
    });

    test('默认测试网: getConfig 返回测试网配置', () {
      expect(ChainRegistry.getConfig('cardano-preview'), isNotNull);
      expect(ChainRegistry.getConfig('cardano-mainnet'), isNull);
    });

    test('主网模式: getConfig 返回主网配置', () {
      AppConfig.isMainnet = true;
      expect(ChainRegistry.getConfig('cardano-mainnet'), isNotNull);
      expect(ChainRegistry.getConfig('cardano-preview'), isNull);
    });

    test('默认测试网: allConfigs 返回测试网配置', () {
      final configs = ChainRegistry.allConfigs();
      expect(configs.any((c) => c.chainId == 'cardano-preview'), isTrue);
      expect(configs.any((c) => c.chainId == 'evm-97'), isTrue);
      expect(configs.any((c) => c.chainId == 'cardano-mainnet'), isFalse);
    });

    test('主网模式: allConfigs 返回主网配置', () {
      AppConfig.isMainnet = true;
      final configs = ChainRegistry.allConfigs();
      expect(configs.any((c) => c.chainId == 'cardano-mainnet'), isTrue);
      expect(configs.any((c) => c.chainId == 'evm-56'), isTrue);
      expect(configs.any((c) => c.chainId == 'cardano-preview'), isFalse);
    });

    test('默认测试网: configsForFamily(evm) 返回 3 条测试网配置', () {
      final evmConfigs = ChainRegistry.configsForFamily('evm');
      expect(evmConfigs.length, 3);
      expect(evmConfigs.any((c) => c.chainId == 'evm-97'), isTrue);
    });

    test('主网模式: configsForFamily(evm) 返回 3 条主网配置', () {
      AppConfig.isMainnet = true;
      final evmConfigs = ChainRegistry.configsForFamily('evm');
      expect(evmConfigs.length, 3);
      expect(evmConfigs.any((c) => c.chainId == 'evm-56'), isTrue);
    });

    test('主网模式: mismatchMessage 使用主网链名', () {
      AppConfig.isMainnet = true;
      final msg = ChainRegistry.mismatchMessage('cardano-mainnet', 'evm-56');
      expect(msg, isNotNull);
      expect(msg!, contains('Cardano Mainnet'));
      expect(msg, contains('BSC'));
    });
  });
}
