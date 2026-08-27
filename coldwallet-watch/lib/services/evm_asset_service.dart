import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../models/evm_asset_balance.dart';
import 'evm_rpc_config.dart';
import 'evm_rpc_service.dart';
import 'storage_service.dart';

/// EVM 资产查询服务
///
/// 通过公共 RPC 查询指定 EVM 地址的原生代币和已添加 ERC-20 代币余额，
/// 返回统一的 [EvmAssetBalance] 列表。
class EvmAssetService {
  final EvmRpcService _rpc;
  final StorageService _storage;

  EvmAssetService(this._rpc, this._storage);

  /// 加载指定钱包在指定链上的资产余额。
  ///
  /// [chainId] 为 [ChainConfig.chainId]，如 `evm-1`、`evm-11155111`。
  /// [address] 为 EVM 观察地址。
  Future<List<EvmAssetBalance>> loadBalances(
    String chainId,
    String address,
  ) async {
    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      throw ArgumentError('Unknown chainId: $chainId');
    }
    final rpcUrl = await _resolveRpcUrl(chainId);

    final results = <EvmAssetBalance>[];

    // 原生代币
    final nativeBalance = await _rpc.getBalance(rpcUrl, address);
    final nativeMeta = _nativeTokenMeta(chainId);
    results.add(
      EvmAssetBalance(
        symbol: nativeMeta.symbol,
        decimals: nativeMeta.decimals,
        balanceInWei: nativeBalance.toString(),
      ),
    );

    // ERC-20 代币
    final contracts = await _storage.getEvmTokenContracts(chainId);
    for (final contract in contracts) {
      try {
        final balance = await _rpc.getTokenBalance(rpcUrl, address, contract);
        final symbol = await _rpc.getTokenSymbol(rpcUrl, contract);
        final decimals = await _rpc.getTokenDecimals(rpcUrl, contract);
        results.add(
          EvmAssetBalance(
            contractAddress: contract,
            symbol: symbol,
            decimals: decimals,
            balanceInWei: balance.toString(),
          ),
        );
      } catch (_) {
        // 单个合约查询失败不影响其他资产展示
      }
    }

    return results;
  }

  Future<String> _resolveRpcUrl(String chainId) =>
      EvmRpcConfig.resolveRpcUrl(_storage, chainId);

  /// 获取原生代币的符号与小数位。
  static _NativeMeta _nativeTokenMeta(String chainId) {
    return switch (chainId) {
      'evm-1' || 'evm-11155111' => _NativeMeta('ETH', 18),
      'evm-56' || 'evm-97' => _NativeMeta('BNB', 18),
      'evm-42161' || 'evm-421614' => _NativeMeta('ETH', 18),
      'evm-137' || 'evm-80002' => _NativeMeta('MATIC', 18),
      'evm-8453' || 'evm-84532' => _NativeMeta('ETH', 18),
      _ => _NativeMeta('ETH', 18),
    };
  }
}

class _NativeMeta {
  final String symbol;
  final int decimals;

  const _NativeMeta(this.symbol, this.decimals);
}
