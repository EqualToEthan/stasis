import 'package:coldwallet_watch/models/evm_asset_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvmAssetBalance', () {
    test('formats whole balance without decimals', () {
      final balance = EvmAssetBalance(
        symbol: 'ETH',
        decimals: 18,
        balanceInWei: '1000000000000000000',
      );
      expect(balance.formattedBalance, '1');
      expect(balance.isNative, isTrue);
    });

    test('formats fractional balance', () {
      final balance = EvmAssetBalance(
        symbol: 'USDC',
        decimals: 6,
        balanceInWei: '1500000',
      );
      expect(balance.formattedBalance, '1.5');
    });

    test('formats zero balance', () {
      final balance = EvmAssetBalance(
        symbol: 'ETH',
        decimals: 18,
        balanceInWei: '0',
      );
      expect(balance.formattedBalance, '0');
    });

    test('serializes and deserializes native token', () {
      final balance = EvmAssetBalance(
        symbol: 'ETH',
        decimals: 18,
        balanceInWei: '1000000000000000000',
      );
      final json = balance.toJson();
      expect(json, {
        'symbol': 'ETH',
        'decimals': 18,
        'balanceInWei': '1000000000000000000',
      });
      final restored = EvmAssetBalance.fromJson(json);
      expect(restored.symbol, 'ETH');
      expect(restored.decimals, 18);
      expect(restored.balanceInWei, '1000000000000000000');
      expect(restored.contractAddress, isNull);
    });

    test('serializes and deserializes erc20 token', () {
      final balance = EvmAssetBalance(
        contractAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        symbol: 'USDT',
        decimals: 6,
        balanceInWei: '5000000',
      );
      final json = balance.toJson();
      expect(
        json['contractAddress'],
        '0xdac17f958d2ee523a2206206994597c13d831ec7',
      );
      final restored = EvmAssetBalance.fromJson(json);
      expect(
        restored.contractAddress,
        '0xdac17f958d2ee523a2206206994597c13d831ec7',
      );
      expect(restored.isNative, isFalse);
    });

    test('copyWith replaces fields', () {
      final balance = EvmAssetBalance(
        contractAddress: '0xabc',
        symbol: 'ABC',
        decimals: 18,
        balanceInWei: '1000',
      );
      final updated = balance.copyWith(balanceInWei: '2000', symbol: 'DEF');
      expect(updated.contractAddress, '0xabc');
      expect(updated.symbol, 'DEF');
      expect(updated.balanceInWei, '2000');
    });

    test('copyWith clearContractAddress makes native', () {
      final balance = EvmAssetBalance(
        contractAddress: '0xabc',
        symbol: 'ABC',
        decimals: 18,
        balanceInWei: '1000',
      );
      final updated = balance.copyWith(clearContractAddress: true);
      expect(updated.contractAddress, isNull);
      expect(updated.isNative, isTrue);
    });
  });
}
