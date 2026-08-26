/// 本地 re-export：从 coldwallet-protocol 共享包导出 ChainRegistry、ChainConfig 和 AppConfig。
///
/// 适配器查找（adapterFor）已移至 [AdapterRegistry]。
/// 详见 ADR-0003。
library;

export 'package:coldwallet_protocol/coldwallet_protocol.dart'
    show ChainRegistry, ChainConfig, AppConfig;
