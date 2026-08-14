import '../models/chain_config.dart';
import 'adapters/cardano_adapter.dart';
import 'adapters/chain_adapter.dart';
import 'adapters/evm_adapter.dart';

/// 链注册中心
///
/// 管理所有支持的链配置，提供适配器实例查找。
/// 新增 EVM 链只需在 _configs 中添加一行 ChainConfig。
class ChainRegistry {
  static const Map<String, ChainConfig> _configs = {
    // Cardano
    'cardano-preview': ChainConfig(
      chainId: 'cardano-preview',
      chainFamily: 'cardano',
      name: 'Cardano Preview',
      network: 'preview',
    ),
    // EVM
    'evm-11155111': ChainConfig(
      chainId: 'evm-11155111',
      chainFamily: 'evm',
      name: 'Ethereum Sepolia',
      network: 'sepolia',
      evmChainId: 11155111,
    ),
    'evm-97': ChainConfig(
      chainId: 'evm-97',
      chainFamily: 'evm',
      name: 'BSC Testnet',
      network: 'testnet',
      evmChainId: 97,
    ),
    'evm-421614': ChainConfig(
      chainId: 'evm-421614',
      chainFamily: 'evm',
      name: 'Arbitrum Sepolia',
      network: 'sepolia',
      evmChainId: 421614,
    ),
    'evm-80002': ChainConfig(
      chainId: 'evm-80002',
      chainFamily: 'evm',
      name: 'Polygon Amoy',
      network: 'amoy',
      evmChainId: 80002,
    ),
    'evm-84532': ChainConfig(
      chainId: 'evm-84532',
      chainFamily: 'evm',
      name: 'Base Sepolia',
      network: 'sepolia',
      evmChainId: 84532,
    ),
  };

  /// 根据链族获取适配器实例
  static ChainAdapter adapterFor(String chainFamily) {
    switch (chainFamily) {
      case 'cardano':
        return CardanoAdapter();
      case 'evm':
        return EvmAdapter();
      default:
        throw UnsupportedError('不支持的链族: $chainFamily');
    }
  }

  /// 根据 chainId 获取链配置
  static ChainConfig? getConfig(String chainId) => _configs[chainId];

  /// 获取所有链配置
  static List<ChainConfig> allConfigs() => _configs.values.toList();

  /// 获取指定链族的所有配置
  static List<ChainConfig> configsForFamily(String family) =>
      _configs.values.where((c) => c.chainFamily == family).toList();
}
