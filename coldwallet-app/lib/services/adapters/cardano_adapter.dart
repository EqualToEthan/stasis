import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import '../../models/certificate.dart';
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

    final WitnessSet witnessSet;
    if (export.certificates != null || export.withdrawals != null) {
      // 质押交易：构建 TxSigningBundle 让 SDK 自动添加 stake key witness
      witnessSet = await _signStakingTransaction(wallet, tx, export);
    } else {
      // 普通支付交易：仅 payment key 签名
      witnessSet = await wallet.signTransaction(
        tx: tx,
        witnessBech32Addresses: {export.summary.fromAddress},
      );
    }

    final signedTx = tx.copyWithAdditionalSignatures(witnessSet);
    final txHash = _blake2b256(HEX.decode(export.txCbor));

    return SignResult(
      signedTxHex: signedTx.serializeHexString(),
      txHash: HEX.encode(txHash),
    );
  }

  /// 质押交易签名：构建 TxSigningBundle，SDK 自动检测证书/提款并添加 stake key witness
  Future<WitnessSet> _signStakingTransaction(
    CardanoWallet wallet,
    CardanoTransaction tx,
    ColdExport export,
  ) async {
    // 从证书中提取质押字段
    final delegationPoolId = export.certificates
        ?.where((c) => c.type == CertificateType.stakeDelegation)
        .map((c) => c.poolKeyHash)
        .nonNulls
        .lastOrNull;
    final hasDeregistration =
        export.certificates?.any(
          (c) => c.type == CertificateType.stakeDeregistration,
        ) ??
        false;

    final bundle = TxSigningBundle(
      receiveAddressBech32: wallet.firstAddress.bech32Encoded,
      networkId: wallet.networkId,
      txsData: [
        TxPreparedForSigning(
          tx: tx,
          txDiff: TxDiff(
            diff: Value.v0(lovelace: BigInt.zero.toCborInt()),
            usedUtxos: const [],
            stakeDelegationPoolId: delegationPoolId,
            stakeDeregistration: hasDeregistration,
            dRepDeregistration: false,
            dRepDelegation: null,
            dRepRegistration: null,
            dRepUpdate: null,
            authorizeConstitutionalCommitteeHot: null,
            resignConstitutionalCommitteeCold: null,
            votes: const [],
            proposals: const [],
          ),
          utxosBeforeTx: const [],
          signingAddressesRequired: {export.summary.fromAddress},
        ),
      ],
      totalDiff: Value.v0(lovelace: BigInt.zero.toCborInt()),
      stakeDelegationPoolId: delegationPoolId,
      stakeDeregistration: hasDeregistration,
      dRepDeregistration: false,
      dRepDelegation: null,
      dRepRegistration: null,
      dRepUpdate: null,
      authorizeConstitutionalCommitteeHot: null,
      resignConstitutionalCommitteeCold: null,
      votes: const [],
      proposals: const [],
    );

    final signedBundle = await wallet.signTransactionsBundle(bundle);
    return signedBundle.txsData[0].nweSignatures;
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
