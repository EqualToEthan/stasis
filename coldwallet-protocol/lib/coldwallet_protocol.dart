/// Stasis 冷热钱包通信协议模型
///
/// 统一导出 Cardano 和 EVM 链族的 ColdExport / ColdImport 数据结构，
/// 供 coldwallet-app（离线签名端）和 coldwallet-watch（联网观察端）共享。
library;

// Cardano
export 'cardano/certificate.dart';
export 'cardano/cold_export.dart';
export 'cardano/cold_import.dart';

// EVM
export 'evm/eth_cold_export.dart';
export 'evm/eth_cold_import.dart';
