import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/services/evm_asset_service.dart';
import 'package:coldwallet_watch/services/evm_rpc_service.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/fake_storage_service.dart';

/// 继承具体实现以覆盖所有 RPC 方法，避免真实网络请求。
class _FakeEvmRpcService extends EvmRpcService {
  final Map<String, BigInt> balances;
  final Map<String, BigInt> tokenBalances;
  final Map<String, String> symbols;
  final Map<String, int> decimals;

  _FakeEvmRpcService({
    this.balances = const {},
    this.tokenBalances = const {},
    this.symbols = const {},
    this.decimals = const {},
  }) : super(client: http.Client());

  @override
  Future<BigInt> getBalance(String rpcUrl, String address) async =>
      balances[address.toLowerCase()] ?? BigInt.zero;

  @override
  Future<BigInt> getTokenBalance(
    String rpcUrl,
    String walletAddress,
    String contractAddress,
  ) async =>
      tokenBalances['${walletAddress.toLowerCase()}:${contractAddress.toLowerCase()}'] ??
      BigInt.zero;

  @override
  Future<String> getTokenSymbol(String rpcUrl, String contractAddress) async {
    final key = contractAddress.toLowerCase();
    if (!symbols.containsKey(key)) {
      throw Exception('Unknown contract: $contractAddress');
    }
    return symbols[key]!;
  }

  @override
  Future<int> getTokenDecimals(String rpcUrl, String contractAddress) async {
    final key = contractAddress.toLowerCase();
    if (!decimals.containsKey(key)) {
      throw Exception('Unknown contract: $contractAddress');
    }
    return decimals[key]!;
  }
}

void main() {
  group('EvmAssetService', () {
    setUp(() {
      // evm-1 等主网 chainId 仅在 mainnet 配置组中，测试前切换到主网。
      AppConfig.isMainnet = true;
    });

    tearDown(() {
      AppConfig.isMainnet = false;
    });
    test('loads native token for Ethereum mainnet', () async {
      final rpc = _FakeEvmRpcService(
        balances: {'0xwallet': BigInt.from(1500000000000000000)},
      );
      final storage = FakeStorageService();
      final service = EvmAssetService(rpc, storage);
      final assets = await service.loadBalances('evm-1', '0xWallet');
      expect(assets.length, 1);
      expect(assets.first.symbol, 'ETH');
      expect(assets.first.formattedBalance, '1.5');
      expect(assets.first.isNative, isTrue);
    });

    test('loads native token and ERC-20 tokens', () async {
      final rpc = _FakeEvmRpcService(
        balances: {'0xwallet': BigInt.from(1000000000000000000)},
        tokenBalances: {'0xwallet:0xusdc': BigInt.from(2000000)},
        symbols: {'0xusdc': 'USDC'},
        decimals: {'0xusdc': 6},
      );
      final storage = FakeStorageService(
        evmTokenContracts: {
          'evm-1': ['0xUSDC'],
        },
      );
      final service = EvmAssetService(rpc, storage);
      final assets = await service.loadBalances('evm-1', '0xWallet');
      expect(assets.length, 2);
      expect(assets[0].symbol, 'ETH');
      expect(assets[0].isNative, isTrue);
      expect(assets[1].symbol, 'USDC');
      expect(assets[1].formattedBalance, '2');
      expect(assets[1].isNative, isFalse);
    });

    test('uses custom RPC URL when configured', () async {
      final rpc = _FakeEvmRpcService(balances: {'0xwallet': BigInt.one});
      final storage = FakeStorageService(
        evmRpcUrls: {'evm-1': 'https://custom.rpc'},
      );
      final service = EvmAssetService(rpc, storage);
      final assets = await service.loadBalances('evm-1', '0xWallet');
      expect(assets.first.balanceInWei, '1');
    });

    test('throws for unknown chainId', () async {
      final rpc = _FakeEvmRpcService();
      final storage = FakeStorageService();
      final service = EvmAssetService(rpc, storage);
      expect(
        () => service.loadBalances('evm-unknown', '0xWallet'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('single ERC-20 failure does not break other tokens', () async {
      final rpc = _FakeEvmRpcService(
        balances: {'0xwallet': BigInt.zero},
        tokenBalances: {'0xwallet:0xgood': BigInt.from(1000)},
        symbols: {'0xgood': 'GOOD'},
        decimals: {'0xgood': 18},
      );
      final storage = FakeStorageService(
        evmTokenContracts: {
          'evm-1': ['0xGood', '0xBad'],
        },
      );
      final service = EvmAssetService(rpc, storage);
      final assets = await service.loadBalances('evm-1', '0xWallet');
      expect(assets.length, 2); // native + good
      expect(assets.any((a) => a.symbol == 'GOOD'), isTrue);
      expect(assets.any((a) => a.contractAddress == '0xBad'), isFalse);
    });

    test('falls back to default RPC URL when custom is not set', () async {
      final rpc = _FakeEvmRpcService(balances: {'0xwallet': BigInt.two});
      final storage = FakeStorageService();
      final service = EvmAssetService(rpc, storage);
      final assets = await service.loadBalances('evm-1', '0xWallet');
      expect(assets.first.balanceInWei, '2');
    });
  });
}
