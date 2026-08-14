import '../../models/chain_config.dart';
import '../../models/sign_result.dart';

/// 链适配器抽象接口
///
/// 每条链族（Cardano / EVM / Bitcoin）提供一个实现，
/// 封装地址派生、交易解析和离线签名的链特有逻辑。
abstract class ChainAdapter {
  /// 链族标识，如 "cardano"、"evm"、"bitcoin"
  String get chainFamily;

  /// 从助记词派生指定链的地址
  ///
  /// [mnemonic] BIP-39 助记词（12 或 24 词）
  /// [config] 目标链的配置信息
  /// 返回链特定格式的地址字符串
  Future<String> deriveAddress(String mnemonic, ChainConfig config);

  /// 解析未签名交易的 JSON 字符串
  ///
  /// [jsonString] 链特有的 ColdExport JSON
  /// 返回链特有的 Export 模型对象
  dynamic parseExport(String jsonString);

  /// 签名交易
  ///
  /// [mnemonic] 当前钱包的助记词
  /// [coldExport] parseExport() 返回的对象
  /// [config] 链配置
  /// 返回统一的 SignResult
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  );
}
