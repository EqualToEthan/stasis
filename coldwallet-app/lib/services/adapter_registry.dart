/// 适配器注册表
///
/// coldwallet-app 专属的链适配器查找表，提供 chainFamily → ChainAdapter 映射。
/// 从 ChainRegistry 拆出，因适配器含私钥派生和签名逻辑，不放入共享包。
///
/// 详见 ADR-0003。
library;

import 'adapters/cardano_adapter.dart';
import 'adapters/chain_adapter.dart';
import 'adapters/evm_adapter.dart';

/// 适配器注册表
class AdapterRegistry {
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
}
