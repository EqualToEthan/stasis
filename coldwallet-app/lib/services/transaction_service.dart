import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import 'adapter_registry.dart';
import 'wallet_service.dart';

/// 交易的发送方地址与当前钱包派生地址不匹配
class WalletMismatchException implements Exception {
  final String message;

  const WalletMismatchException(this.message);

  @override
  String toString() => message;
}

/// 未签名交易的网络标识与当前应用网络配置不匹配
class NetworkMismatchException implements Exception {
  final String message;

  const NetworkMismatchException(this.message);

  @override
  String toString() => message;
}

/// 交易服务：解析未签名交易、签名、导出已签名交易
class TransactionService {
  final WalletService _walletService;

  TransactionService(this._walletService);

  /// 从 JSON 字符串解析 ColdExport
  ///
  /// [jsonString] ColdExport 的 JSON 序列化字符串
  ColdExport parseColdExport(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return ColdExport.fromJson(json);
  }

  /// 签名交易并返回 ColdImport
  ///
  /// 使用 cardano_flutter_sdk 解析 CBOR 交易体，用本地私钥签名，
  /// 再组装出完整的已签名交易 CBOR 与交易哈希。
  Future<ColdImport> signTransaction(ColdExport coldExport) async {
    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('当前钱包未初始化或助记词丢失');
    }
    final passphrase = await _walletService.loadCurrentPassphrase();

    final wallet = await _walletService.createWallet(
      mnemonic,
      passphrase: passphrase,
    );

    final tx = CardanoTransaction.deserializeFromHex(coldExport.txCbor);
    final witnessSet = await wallet.signTransaction(
      tx: tx,
      witnessBech32Addresses: {coldExport.summary.fromAddress},
    );
    final signedTx = tx.copyWithAdditionalSignatures(witnessSet);

    // Cardano 交易哈希 = blake2b_256(transaction body)
    final txHash = _blake2b256(HEX.decode(coldExport.txCbor));

    return ColdImport(
      version: 1,
      type: 'signed-tx',
      txCbor: signedTx.serializeHexString(),
      txHash: HEX.encode(txHash),
    );
  }

  /// 计算 blake2b_256 哈希
  ///
  /// 用于计算 Cardano 交易哈希 = blake2b_256(transaction body CBOR)
  Uint8List _blake2b256(List<int> input) {
    final digest = Blake2bDigest(digestSize: 32);
    digest.update(Uint8List.fromList(input), 0, input.length);
    final result = Uint8List(32);
    digest.doFinal(result, 0);
    return result;
  }

  /// 统一签名入口 — 自动识别链类型并路由到对应适配器
  ///
  /// 签名前先派生当前钱包地址，与未签名交易中的 fromAddress 比对，
  /// 不匹配时抛出异常，防止用错误钱包签名他人交易。
  ///
  /// [rawJson] 来自扫码或剪贴板导入的 JSON 字符串。
  /// 无 chainId 字段时视为 Cardano ColdExport（向后兼容）。
  /// 返回通用的签名结果 JSON Map。
  ///
  /// 抛出 [Exception] 当派生地址与交易 fromAddress 不匹配时。
  Future<Map<String, dynamic>> signForChain(String rawJson) async {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('当前钱包未初始化或助记词丢失');
    }
    final passphrase = await _walletService.loadCurrentPassphrase();

    if (chainId == null) {
      // 向后兼容：Cardano ColdExport
      final coldExport = ColdExport.fromJson(json);
      // 跨设备网络校验：防止两端 app 版本不同步导致网络不匹配
      final expectedNetwork = AppConfig.isMainnet ? 'mainnet' : 'preview';
      if (coldExport.network != expectedNetwork) {
        throw const NetworkMismatchException('两端网络配置不匹配，请同时更新两个应用');
      }
      final config =
          ChainRegistry.configsForFamily('cardano').firstOrNull ??
          ChainRegistry.getConfig(
            AppConfig.isMainnet ? 'cardano-mainnet' : 'cardano-preview',
          )!;
      final derivedAddress = await _walletService.deriveAddressForChain(
        mnemonic,
        config,
        passphrase: passphrase,
      );
      if (derivedAddress != coldExport.summary.fromAddress) {
        throw const WalletMismatchException('未签名交易与当前钱包不匹配，请检查是否使用了正确的钱包');
      }
      final coldImport = await signTransaction(coldExport);
      return coldImport.toJson();
    }

    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      throw UnsupportedError('不支持的链: $chainId');
    }

    final adapter = AdapterRegistry.adapterFor(config.chainFamily);
    final export = adapter.parseExport(rawJson);
    final derivedAddress = await adapter.deriveAddress(
      mnemonic,
      config,
      passphrase: passphrase,
    );
    final fromAddress = _extractFromAddress(export, config.chainFamily);
    if (!_addressesMatch(derivedAddress, fromAddress, config.chainFamily)) {
      throw const WalletMismatchException('未签名交易与当前钱包不匹配，请检查是否使用了正确的钱包');
    }

    final result = await adapter.signTransaction(
      mnemonic,
      export,
      config,
      passphrase: passphrase,
    );

    return {
      'version': result.version,
      'type': 'signed-tx',
      'rawTxHex': result.signedTxHex,
      'txHash': result.txHash,
    };
  }

  /// 从未签名交易模型中提取发送方地址
  ///
  /// [export] 已解析的未签名交易模型（ColdExport 或 EthColdExport）。
  /// [chainFamily] 链族标识（'cardano' 或 'evm'）。
  /// 返回对应模型的 summary.fromAddress。
  String _extractFromAddress(dynamic export, String chainFamily) {
    if (chainFamily == 'cardano') {
      return (export as ColdExport).summary.fromAddress;
    }
    if (chainFamily == 'evm') {
      return (export as EthColdExport).summary.fromAddress;
    }
    throw UnsupportedError('不支持的链族: $chainFamily');
  }

  /// 比较派生地址与交易发送方地址是否匹配
  ///
  /// EVM 地址按 EIP-55 校验和编码，比较时忽略大小写；
  /// Cardano bech32 地址保持精确匹配。
  bool _addressesMatch(String derived, String from, String chainFamily) {
    if (chainFamily == 'evm') {
      return derived.toLowerCase() == from.toLowerCase();
    }
    return derived == from;
  }
}
