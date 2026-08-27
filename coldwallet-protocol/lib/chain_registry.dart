/// 链注册中心
///
/// 管理所有受支持链配置的静态注册表，提供 chainId → ChainConfig 查找。
/// 维护测试网和主网两组配置，按 [AppConfig.isMainnet] 选组。
/// 两个 app（coldwallet-app 和 coldwallet-watch）共享此注册表。
///
/// 适配器查找（chainFamily → ChainAdapter）已拆分到 coldwallet-app 的 AdapterRegistry，
/// 因适配器含私钥派生和签名逻辑，不放入共享包。
///
/// 详见 ADR-0003。
library;

import 'app_config.dart';
import 'chain_config.dart';

/// 链注册中心
class ChainRegistry {
  /// 测试网配置组
  static const Map<String, ChainConfig> _testnetConfigs = {
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
    'evm-84532': ChainConfig(
      chainId: 'evm-84532',
      chainFamily: 'evm',
      name: 'Base Sepolia',
      network: 'sepolia',
      evmChainId: 84532,
    ),
  };

  /// 主网配置组
  static const Map<String, ChainConfig> _mainnetConfigs = {
    // Cardano
    'cardano-mainnet': ChainConfig(
      chainId: 'cardano-mainnet',
      chainFamily: 'cardano',
      name: 'Cardano Mainnet',
      network: 'mainnet',
    ),
    // EVM
    'evm-1': ChainConfig(
      chainId: 'evm-1',
      chainFamily: 'evm',
      name: 'Ethereum',
      network: 'mainnet',
      evmChainId: 1,
    ),
    'evm-56': ChainConfig(
      chainId: 'evm-56',
      chainFamily: 'evm',
      name: 'BSC',
      network: 'mainnet',
      evmChainId: 56,
    ),
    'evm-42161': ChainConfig(
      chainId: 'evm-42161',
      chainFamily: 'evm',
      name: 'Arbitrum',
      network: 'mainnet',
      evmChainId: 42161,
    ),
    'evm-8453': ChainConfig(
      chainId: 'evm-8453',
      chainFamily: 'evm',
      name: 'Base',
      network: 'mainnet',
      evmChainId: 8453,
    ),
  };

  /// 当前激活的配置组（按 AppConfig.isMainnet 选组）
  static Map<String, ChainConfig> get _activeConfigs =>
      AppConfig.isMainnet ? _mainnetConfigs : _testnetConfigs;

  /// 根据 chainId 获取链配置
  static ChainConfig? getConfig(String chainId) => _activeConfigs[chainId];

  /// 获取所有链配置
  static List<ChainConfig> allConfigs() => _activeConfigs.values.toList();

  /// 获取指定链族的所有配置
  static List<ChainConfig> configsForFamily(String family) =>
      _activeConfigs.values.where((c) => c.chainFamily == family).toList();

  /// 从交易 JSON 解析链 ID。
  ///
  /// 无 `chainId` 字段或值为非 String 时视为 Cardano，
  /// 按 [AppConfig.isMainnet] 返回 'cardano-mainnet' 或 'cardano-preview'，
  /// 向后兼容不含 chainId 字段的 ColdExport。
  static String resolveChainId(Map<String, dynamic> json) {
    final v = json['chainId'];
    if (v is String) return v;
    return AppConfig.isMainnet ? 'cardano-mainnet' : 'cardano-preview';
  }

  /// 生成"链不匹配"提示文案，匹配时返回 null。
  ///
  /// [selectedChainId] 当前选中的链 ID；
  /// [scannedChainId] 扫码/导入交易解析出的链 ID。
  /// 链名取不到时回退显示原始 chainId。
  static String? mismatchMessage(
    String selectedChainId,
    String scannedChainId,
  ) {
    if (scannedChainId == selectedChainId) return null;
    final selected = getConfig(selectedChainId)?.name ?? selectedChainId;
    final scanned = getConfig(scannedChainId)?.name ?? scannedChainId;
    return '当前选中 $selected，扫到的交易属于 $scanned，请切换链后重试';
  }
}
