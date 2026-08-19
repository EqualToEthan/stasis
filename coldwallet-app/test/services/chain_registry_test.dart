import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/chain_registry.dart';

void main() {
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

  group('ChainRegistry.mismatchMessage', () {
    test('returns null when chains match', () {
      expect(
        ChainRegistry.mismatchMessage('cardano-preview', 'cardano-preview'),
        isNull,
      );
    });

    test('returns message with friendly names on mismatch', () {
      final msg = ChainRegistry.mismatchMessage('evm-11155111', 'evm-97');
      expect(msg, isNotNull);
      expect(msg!, contains('Ethereum Sepolia'));
      expect(msg, contains('BSC Testnet'));
      expect(msg, contains('请切换链后重试'));
    });

    test('falls back to raw chainId when config not found', () {
      final msg = ChainRegistry.mismatchMessage(
        'evm-11155111',
        'unknown-chain',
      );
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
      final msg = ChainRegistry.mismatchMessage('evm-11155111', scanned);
      expect(msg, isNotNull);
      expect(msg!, contains('Ethereum Sepolia'));
      expect(msg, contains('Cardano Preview'));
    });
  });
}
