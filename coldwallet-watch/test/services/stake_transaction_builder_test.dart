import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:coldwallet_protocol/coldwallet_protocol.dart'
    hide Certificate, CertificateType;
import 'package:coldwallet_protocol/cardano/certificate.dart' as proto_cert;
import 'package:coldwallet_watch/services/blockfrost_service.dart';
import 'package:coldwallet_watch/services/stake_transaction_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用户报告失败的未签名委托交易（FeeTooSmallUTxO：supplied 165325，expected 174257）
const _failingUnsignedTxJson =
    '{"version":1,"type":"unsigned-tx","network":"preview","txCbor":"84a6008182582024f74711cb06cdd980eca9882bbc5f551c2f4dba3e339a33bf61bd96e29cf10a000181a2005839009784c27b20500c34b02fb1480ddbad380edd0eec0be93078ab0d36f6ecc9d49e2a7488b5efd82339319d98b4d91f78fff7cc201da74c7b8f011a02d9e633021a000285cd031a072fb05a048282008200581cecc9d49e2a7488b5efd82339319d98b4d91f78fff7cc201da74c7b8f83028200581cecc9d49e2a7488b5efd82339319d98b4d91f78fff7cc201da74c7b8f581c24d3394028c590692542c932784632147319b6c50e1c17805de044c60f00a0f5f6","summary":{"fromAddress":"addr_test1qztcfsnmypgqcd9s97c5srwm45uqahgwas97jvrc4vxndahve82fu2n53z67lkpr8ycemx95my0h3llhesspmf6v0w8shgxz6l","toAddress":"addr_test1qztcfsnmypgqcd9s97c5srwm45uqahgwas97jvrc4vxndahve82fu2n53z67lkpr8ycemx95my0h3llhesspmf6v0w8shgxz6l","assets":[{"unit":"lovelace","quantity":"0"}],"fee":"165325"},"certificates":[{"type":"stakeRegistration","stakeCredential":"ecc9d49e2a7488b5efd82339319d98b4d91f78fff7cc201da74c7b8f"},{"type":"stakeDelegation","stakeCredential":"ecc9d49e2a7488b5efd82339319d98b4d91f78fff7cc201da74c7b8f","poolKeyHash":"pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt"}],"stakeKeyPath":"m/1852\'/1815\'/0\'/2/0"}';

Uint8List _randomBytes(int length) {
  final random = Random(42);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

String _testnetPaymentAddress(Uint8List paymentCred, Uint8List stakeCred) {
  final bytes = Uint8List(57)
    ..[0] =
        0x00 // base address, key/key, testnet
    ..setRange(1, 29, paymentCred)
    ..setRange(29, 57, stakeCred);
  return bytes.bech32Encode('addr_test');
}

String _testnetStakeAddress(Uint8List stakeCred) {
  final bytes = Uint8List(29)
    ..[0] =
        0xe0 // reward address, key, testnet
    ..setRange(1, 29, stakeCred);
  return bytes.bech32Encode('stake_test');
}

WitnessSet _twoDummyWitnesses() => WitnessSet(
  ivkeyWitnesses: ListWithCborType(
    [
      WitnessVKey(vkey: Uint8List(32), signature: Uint8List(64)),
      WitnessVKey(vkey: Uint8List(32), signature: Uint8List(64)),
    ],
    CborLengthType.definite,
    [],
  ),
);

class _MockBlockfrost extends BlockfrostService {
  _MockBlockfrost() : super(apiKey: 'test', network: 'preview');

  @override
  Future<List<Map<String, dynamic>>> getAddressUtxos(String address) async => [
    {
      'tx_hash':
          '24f74711cb06cdd980eca9882bbc5f551c2f4dba3e339a33bf61bd96e29cf10a',
      'output_index': 0,
      'amount': [
        {'unit': 'lovelace', 'quantity': '100000000'},
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> getLatestBlock() async => {'slot': 120000000};

  @override
  Future<Map<String, dynamic>> getProtocolParams() async => {
    'min_fee_a': 44,
    'min_fee_b': 155381,
  };
}

void main() {
  group('StakeTransactionBuilder', () {
    test(
      'regression: supplied fee 165325 does not cover signed tx size (expected 174257)',
      () {
        final export = ColdExport.fromJson(
          jsonDecode(_failingUnsignedTxJson) as Map<String, dynamic>,
        );
        final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
        final signedTx = bodyTx.copyWithAdditionalSignatures(
          _twoDummyWitnesses(),
        );

        const minFeeA = 44;
        const minFeeB = 155381;
        final requiredFee =
            minFeeA * signedTx.serializeAsBytes().length + minFeeB;

        // 链上实际报错 expected 174257；用 dummy witness 估算会略高一点（174301），
        // 这里只断言 supplied fee 不足以覆盖签名后大小。
        expect(
          BigInt.parse(export.summary.fee),
          lessThan(BigInt.from(requiredFee)),
          reason: '未签名交易估算的 fee 未包含 payment + stake witness 大小',
        );
      },
    );

    test('delegate fee covers payment + stake witnesses after fix', () async {
      final paymentCred = _randomBytes(28);
      final stakeCred = _randomBytes(28);
      final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
      final stakeAddress = _testnetStakeAddress(stakeCred);

      final builder = StakeTransactionBuilder(_MockBlockfrost());
      final export = await builder.buildDelegate(
        fromAddress: fromAddress,
        stakeAddress: stakeAddress,
        poolIdBech32:
            'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        network: 'preview',
        isStakeRegistered: false,
      );

      final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
      final signedTx = bodyTx.copyWithAdditionalSignatures(
        _twoDummyWitnesses(),
      );
      final signedBytes = signedTx.serializeAsBytes();
      const minFeeA = 44;
      const minFeeB = 155381;
      final requiredFee = minFeeA * signedBytes.length + minFeeB;

      expect(
        BigInt.parse(export.summary.fee),
        greaterThanOrEqualTo(BigInt.from(requiredFee)),
        reason: 'builder 估算的 fee 必须覆盖签名后交易大小（payment + stake witness）',
      );
      expect(
        export.summary.deposit,
        '2000000',
        reason: '首次委托应在 summary 中标注 2 ADA 质押押金',
      );
    });

    test(
      'delegate includes registration, pool delegation and abstain certificates',
      () async {
        final paymentCred = _randomBytes(28);
        final stakeCred = _randomBytes(28);
        final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
        final stakeAddress = _testnetStakeAddress(stakeCred);

        final builder = StakeTransactionBuilder(_MockBlockfrost());
        final export = await builder.buildDelegate(
          fromAddress: fromAddress,
          stakeAddress: stakeAddress,
          poolIdBech32:
              'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
          network: 'preview',
          isStakeRegistered: false,
        );

        // 交易体 CBOR：注册 + pool 委托 + DRep 弃权三证书
        final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
        final certs = bodyTx.body.certs!.certificates;
        expect(
          certs.whereType<Certificate_StakeRegistrationLegacy>().length,
          1,
          reason: '首次委托必须包含 stake registration 证书',
        );
        expect(
          certs.whereType<Certificate_StakeDelegation>().length,
          1,
          reason: '必须包含 pool 委托证书',
        );
        expect(
          certs.whereType<Certificate_VoteDelegation>().length,
          1,
          reason: '必须随委托附带 DRep 弃权证书（ADR 0004）',
        );
        expect(bodyTx.body.withdrawals, isNull, reason: '委托交易不应包含 withdrawal');

        // ColdExport 证书摘要：类型与字段语义正确
        final exportCerts = export.certificates!;
        expect(exportCerts, hasLength(3));
        final voteCert = exportCerts
            .where((c) => c.type == proto_cert.CertificateType.voteDelegation)
            .single;
        expect(voteCert.dRepType, proto_cert.DRepType.abstain);
        expect(voteCert.poolKeyHash, isNull);
        expect(
          exportCerts
              .where(
                (c) => c.type == proto_cert.CertificateType.stakeDelegation,
              )
              .single
              .poolKeyHash,
          'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
        );
      },
    );

    test(
      're-delegation carries abstain certificate but no registration/deposit',
      () async {
        final paymentCred = _randomBytes(28);
        final stakeCred = _randomBytes(28);
        final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
        final stakeAddress = _testnetStakeAddress(stakeCred);

        final builder = StakeTransactionBuilder(_MockBlockfrost());
        final export = await builder.buildDelegate(
          fromAddress: fromAddress,
          stakeAddress: stakeAddress,
          poolIdBech32:
              'pool1ynfnjspgckgxjf2zeye8s33jz3e3ndk9pcwp0qzaupzvvd8ukwt',
          network: 'preview',
          isStakeRegistered: true,
        );

        // 已注册账户重新委托：无注册证书、无押金，但弃权证书仍然附带（幂等）
        final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
        final certs = bodyTx.body.certs!.certificates;
        expect(certs.whereType<Certificate_StakeRegistrationLegacy>(), isEmpty);
        expect(
          certs.whereType<Certificate_VoteDelegation>().length,
          1,
          reason: '重新委托同样附带弃权证书，保证前提条件成立',
        );
        expect(export.summary.deposit, isNull);
      },
    );

    test('deregister includes negative deposit for refund', () async {
      final paymentCred = _randomBytes(28);
      final stakeCred = _randomBytes(28);
      final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
      final stakeAddress = _testnetStakeAddress(stakeCred);

      final builder = StakeTransactionBuilder(_MockBlockfrost());
      final export = await builder.buildDeregister(
        fromAddress: fromAddress,
        stakeAddress: stakeAddress,
        network: 'preview',
      );

      expect(
        export.summary.deposit,
        '-2000000',
        reason: '解除注册应标注负数 deposit 表示退回 2 ADA',
      );
      expect(export.certificates, isNotNull);
      expect(
        export.certificates!.first.type,
        proto_cert.CertificateType.stakeDeregistration,
      );
    });

    test(
      'deregister without rewards succeeds (caller must ensure zero balance)',
      () async {
        final paymentCred = _randomBytes(28);
        final stakeCred = _randomBytes(28);
        final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
        final stakeAddress = _testnetStakeAddress(stakeCred);

        final builder = StakeTransactionBuilder(_MockBlockfrost());
        final export = await builder.buildDeregister(
          fromAddress: fromAddress,
          stakeAddress: stakeAddress,
          network: 'preview',
        );

        // 解除注册证书存在，无 withdrawals
        expect(export.certificates, isNotNull);
        expect(
          export.certificates!.first.type,
          proto_cert.CertificateType.stakeDeregistration,
        );
        expect(export.withdrawals, isNull);

        // deposit 退回仍然是负数
        expect(export.summary.deposit, '-2000000');
      },
    );

    test(
      'withdraw reward no longer includes vote delegation in same transaction',
      () async {
        final paymentCred = _randomBytes(28);
        final stakeCred = _randomBytes(28);
        final fromAddress = _testnetPaymentAddress(paymentCred, stakeCred);
        final stakeAddress = _testnetStakeAddress(stakeCred);

        final builder = StakeTransactionBuilder(_MockBlockfrost());
        final export = await builder.buildWithdrawReward(
          fromAddress: fromAddress,
          stakeAddress: stakeAddress,
          withdrawableAmount: BigInt.from(63804),
          network: 'preview',
        );

        final bodyTx = CardanoTransaction.deserializeFromHex(export.txCbor);
        final certs = bodyTx.body.certs;
        final withdrawals = bodyTx.body.withdrawals;

        expect(certs, isNull, reason: '提取奖励交易不应再附带证书');
        expect(withdrawals, isNotNull, reason: '必须包含 reward withdrawal');
        expect(
          export.withdrawals,
          equals({stakeAddress: 63804}),
          reason: 'ColdExport 应携带提款摘要',
        );
      },
    );
  });
}
