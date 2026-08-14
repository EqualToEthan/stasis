import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import '../models/cold_export.dart';
import '../models/cold_import.dart';
import 'chain_registry.dart';
import 'wallet_service.dart';

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

    final wallet = await _walletService.createWallet(
      mnemonic,
      testnet: coldExport.network != 'mainnet',
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
  /// [rawJson] 来自扫码或文件导入的 JSON 字符串。
  /// 无 chainId 字段时视为 Cardano ColdExport（向后兼容）。
  /// 返回通用的签名结果 JSON Map。
  Future<Map<String, dynamic>> signForChain(String rawJson) async {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final chainId = json['chainId'] as String?;

    final mnemonic = await _walletService.loadCurrentMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      throw Exception('当前钱包未初始化或助记词丢失');
    }

    if (chainId == null) {
      // 向后兼容：Cardano ColdExport
      final coldExport = ColdExport.fromJson(json);
      final coldImport = await signTransaction(coldExport);
      return coldImport.toJson();
    }

    final config = ChainRegistry.getConfig(chainId);
    if (config == null) {
      throw UnsupportedError('不支持的链: $chainId');
    }

    final adapter = ChainRegistry.adapterFor(config.chainFamily);
    final export = adapter.parseExport(rawJson);
    final result = await adapter.signTransaction(mnemonic, export, config);

    return {
      'version': result.version,
      'type': 'signed-tx',
      'rawTxHex': result.signedTxHex,
      'txHash': result.txHash,
    };
  }
}
