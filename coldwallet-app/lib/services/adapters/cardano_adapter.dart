import 'dart:convert';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:coldwallet_protocol/coldwallet_protocol.dart';
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
  Future<String> deriveAddress(
    String mnemonic,
    ChainConfig config, {
    String passphrase = '',
  }) async {
    final wallet = await _createCardanoWallet(mnemonic, passphrase: passphrase);
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
    ChainConfig config, {
    String passphrase = '',
  }) async {
    final export = coldExport as ColdExport;

    final wallet = await _createCardanoWallet(mnemonic, passphrase: passphrase);

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

    // 从交易体中检测当前钱包 stake key 的 DRep 委托证书。
    // Conway 时代奖励提取需要 DRep 委托；把 dRepDelegation 传给 SDK
    // 可确保签名 bundle 与交易体语义一致。
    final Drep? dRepDelegation = _extractDRepDelegation(tx, wallet);

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
            dRepDelegation: dRepDelegation,
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
      dRepDelegation: dRepDelegation,
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

  /// 从交易体中提取与当前钱包 stake key 匹配的 DRep 委托。
  ///
  /// 仅当 [tx.body.certs] 中存在针对 [wallet.stakeAddress] 的
  /// [Certificate_VoteDelegation] 时才返回其 [Drep]，否则返回 null。
  Drep? _extractDRepDelegation(CardanoTransaction tx, CardanoWallet wallet) {
    final certs = tx.body.certs?.certificates;
    if (certs == null || certs.isEmpty) return null;

    final stakeCredBytes = wallet.stakeAddress.credentialsBytes;
    for (final cert in certs) {
      if (cert is Certificate_VoteDelegation) {
        final credBytes = cert.stakeCredential.vKeyHash;
        if (credBytes.length == stakeCredBytes.length &&
            credBytes.every((b) => b == stakeCredBytes[credBytes.indexOf(b)])) {
          return cert.dRep;
        }
      }
    }
    return null;
  }

  /// 创建 CardanoWallet，支持可选 BIP-39 密码短语
  ///
  /// 当 passphrase 非空时，通过 BIP-39 mnemonic + passphrase 生成种子再创建钱包，
  /// 相同助记词 + 不同密码短语会产生完全不同的地址。
  ///
  /// 网络由 [AppConfig.isMainnet] 全局控制。
  Future<CardanoWallet> _createCardanoWallet(
    String mnemonic, {
    String passphrase = '',
  }) async {
    final network = AppConfig.isMainnet ? NetworkId.mainnet : NetworkId.testnet;
    if (passphrase.isEmpty) {
      return WalletFactory.fromMnemonic(
        network,
        mnemonic.trim().split(RegExp(r'\s+')),
      );
    }
    final seed = bip39.mnemonicToSeed(mnemonic.trim(), passphrase: passphrase);
    final hdWallet = HdWallet.fromSeed(seed);
    return WalletFactory.fromHdWallet(network, hdWallet);
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
