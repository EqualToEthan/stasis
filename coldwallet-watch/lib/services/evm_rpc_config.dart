import 'storage_service.dart';

/// EVM 链默认 RPC 端点配置
///
/// 为 coldwallet-watch 中已支持的 EVM 链提供默认公共 RPC URL。
/// 所有端点均为免费、无需 API key 的公共服务。
/// 用户可在设置页覆盖任意链的 RPC 端点；未覆盖时使用本配置中的默认值。
class EvmRpcConfig {
  /// 默认公共 RPC 端点表，按 [ChainConfig.chainId] 索引。
  ///
  /// 端点选择原则：免费、无需 API key、社区维护。
  /// 若某个端点不可用，用户可在设置页自行覆盖。
  static const Map<String, String> defaultRpcUrls = {
    // 主网
    'evm-1': 'https://eth.llamarpc.com',
    'evm-56': 'https://bsc-dataseed.binance.org',
    'evm-42161': 'https://arb1.arbitrum.io/rpc',
    'evm-137': 'https://polygon.llamarpc.com',
    'evm-8453': 'https://mainnet.base.org',
    // 测试网
    'evm-11155111': 'https://ethereum-sepolia-rpc.publicnode.com',
    'evm-97': 'https://data-seed-prebsc-1-s1.binance.org:8545',
    'evm-421614': 'https://sepolia-rollup.arbitrum.io/rpc',
    'evm-80002': 'https://rpc-amoy.polygon.technology',
    'evm-84532': 'https://sepolia.base.org',
  };

  /// 获取指定链的默认 RPC URL；未配置时返回 null。
  static String? getDefaultRpcUrl(String chainId) => defaultRpcUrls[chainId];

  /// 解析最终使用的 RPC URL。
  ///
  /// 优先使用 [storage] 中保存的用户自定义 URL，
  /// 不存在时回退到 [defaultRpcUrls]；两者都未配置则抛出 [StateError]。
  static Future<String> resolveRpcUrl(
    StorageService storage,
    String chainId,
  ) async {
    final custom = await storage.getEvmRpcUrl(chainId);
    if (custom != null && custom.isNotEmpty) return custom;

    final fallback = getDefaultRpcUrl(chainId);
    if (fallback != null && fallback.isNotEmpty) return fallback;

    throw StateError('No RPC URL configured for chain $chainId');
  }
}
