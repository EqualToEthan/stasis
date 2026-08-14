import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import '../../models/chain_config.dart';
import '../../models/cold_export.dart';
import '../../models/sign_result.dart';
import 'chain_adapter.dart';

/// Cardano 链适配器
///
/// 封装 Cardano 的地址派生（CIP-1852）、交易解析（CBOR）和离线签名（Ed25519）。
/// 从现有 WalletService / TransactionService 中提取的链特有逻辑。
class CardanoAdapter implements ChainAdapter {
  @override
  String get chainFamily => 'cardano';

  @override
  Future<String> deriveAddress(String mnemonic, ChainConfig config) async {
    final isTestnet = config.network != 'mainnet';
    final wallet = await WalletFactory.fromMnemonic(
      isTestnet ? NetworkId.testnet : NetworkId.mainnet,
      mnemonic.trim().split(RegExp(r'\s+')),
    );
    final addrKit = await wallet.getPaymentAddressKit(addressIndex: 0);
    return addrKit.address.bech32Encoded;
  }

  @override
  ColdExport parseExport(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return ColdExport.fromJson(json);
  }

  @override
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  ) async {
    final export = coldExport as ColdExport;
    final isTestnet = export.network != 'mainnet';

    final wallet = await WalletFactory.fromMnemonic(
      isTestnet ? NetworkId.testnet : NetworkId.mainnet,
      mnemonic.trim().split(RegExp(r'\s+')),
    );

    final tx = CardanoTransaction.deserializeFromHex(export.txCbor);
    final witnessSet = await wallet.signTransaction(
      tx: tx,
      witnessBech32Addresses: {export.summary.fromAddress},
    );
    final signedTx = tx.copyWithAdditionalSignatures(witnessSet);

    final txHash = _blake2b256(HEX.decode(export.txCbor));

    return SignResult(
      signedTxHex: signedTx.serializeHexString(),
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
}
