import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/crypto.dart' as web3crypto;
import 'package:web3dart/web3dart.dart';

import '../../models/chain_config.dart';
import '../../models/eth_cold_export.dart';
import '../../models/sign_result.dart';
import 'chain_adapter.dart';

/// EVM 链适配器。
///
/// 覆盖所有 EVM 兼容链（Ethereum、BSC、Arbitrum、Polygon、Base 等），
/// 通过 [ChainConfig.evmChainId] 区分不同链。使用 secp256k1 密钥派生
/// （BIP-44 m/44'/60'/0'/0/0）和 EIP-155 / EIP-1559 交易签名。
class EvmAdapter implements ChainAdapter {
  static final BigInt _secp256k1Order = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  @override
  String get chainFamily => 'evm';

  @override
  Future<String> deriveAddress(String mnemonic, ChainConfig config) async {
    final privateKey = _derivePrivateKey(mnemonic);
    return privateKey.address.hex;
  }

  @override
  EthColdExport parseExport(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return EthColdExport.fromJson(json);
  }

  @override
  Future<SignResult> signTransaction(
    String mnemonic,
    dynamic coldExport,
    ChainConfig config,
  ) async {
    final export = coldExport as EthColdExport;
    final chainId = config.evmChainId;
    if (chainId == null) {
      throw ArgumentError('EVM chain config must include evmChainId');
    }

    final privateKey = _derivePrivateKey(mnemonic);
    final rawTxBytes = _hexToBytes(export.rawTxHex);
    final signedTxBytes = _signRawUnsignedTransaction(
      rawTxBytes,
      privateKey,
      chainId,
    );
    final txHash = web3crypto.keccak256(signedTxBytes);

    return SignResult(
      signedTxHex: '0x${HEX.encode(signedTxBytes)}',
      txHash: '0x${HEX.encode(txHash)}',
    );
  }

  /// 使用 BIP-39 seed 和 BIP-32 派生路径 m/44'/60'/0'/0/0 派生 EVM 私钥。
  EthPrivateKey _derivePrivateKey(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic.trim());
    final master = _hmacSha512(utf8.encode('Bitcoin seed'), seed);

    var key = master.sublist(0, 32);
    var chainCode = master.sublist(32);

    const hardenedOffset = 0x80000000;
    final indices = <int>[
      hardenedOffset + 44,
      hardenedOffset + 60,
      hardenedOffset,
      0,
      0,
    ];

    for (final index in indices) {
      final data = Uint8List(37);
      if (index >= hardenedOffset) {
        data[0] = 0;
        data.setRange(1, 33, key);
      } else {
        data.setRange(0, 33, _compressedPublicKey(key));
      }
      data[33] = (index >> 24) & 0xff;
      data[34] = (index >> 16) & 0xff;
      data[35] = (index >> 8) & 0xff;
      data[36] = index & 0xff;

      final derived = _hmacSha512(chainCode, data);
      final il = derived.sublist(0, 32);
      final ir = derived.sublist(32);
      final ilInt = _bytesToBigInt(il);

      if (ilInt >= _secp256k1Order) {
        throw StateError('Invalid BIP-32 child key: IL >= curve order');
      }

      final childInt = (ilInt + _bytesToBigInt(key)) % _secp256k1Order;
      if (childInt == BigInt.zero) {
        throw StateError('Invalid BIP-32 child key: zero private key');
      }

      key = _bigIntToBytes(childInt, length: 32);
      chainCode = ir;
    }

    return EthPrivateKey(key);
  }

  Uint8List _signRawUnsignedTransaction(
    Uint8List rawTxBytes,
    EthPrivateKey privateKey,
    int chainId,
  ) {
    if (rawTxBytes.isEmpty) {
      throw ArgumentError('rawTxHex must not be empty');
    }

    // EIP-1559 typed transaction: 0x02 || rlp([chainId, nonce, maxPriorityFee,
    // maxFee, gasLimit, to, value, data, accessList]). The signing payload is
    // exactly the typed unsigned transaction bytes, and the signed transaction is
    // 0x02 || rlp([...unsignedFields, yParity, r, s]).
    if (rawTxBytes.first == 0x02) {
      final decoded = _rlpDecode(rawTxBytes.sublist(1));
      if (decoded is! List) {
        throw FormatException(
          'EIP-1559 transaction payload must be an RLP list',
        );
      }
      if (decoded.length != 9) {
        throw FormatException(
          'EIP-1559 unsigned transaction must contain 9 fields',
        );
      }

      final signature = privateKey.signToEcSignature(
        rawTxBytes,
        chainId: chainId,
        isEIP1559: true,
      );
      final signedPayload = _rlpEncode([
        ...decoded,
        signature.v,
        signature.r,
        signature.s,
      ]);
      return Uint8List.fromList([0x02, ...signedPayload]);
    }

    // Legacy EIP-155 fallback. The primary export format is EIP-1559, but this
    // keeps the adapter compatible with unsigned legacy RLP payloads as well.
    final decoded = _rlpDecode(rawTxBytes);
    if (decoded is! List) {
      throw FormatException('Legacy transaction payload must be an RLP list');
    }

    late final Uint8List signingPayload;
    late final List<dynamic> transactionFields;
    if (decoded.length == 9) {
      signingPayload = rawTxBytes;
      transactionFields = decoded.sublist(0, 6);
    } else if (decoded.length == 6) {
      transactionFields = decoded;
      signingPayload = _rlpEncode([...decoded, chainId, 0, 0]);
    } else {
      throw FormatException(
        'Legacy unsigned transaction must contain 6 or 9 fields',
      );
    }

    final signature = privateKey.signToEcSignature(
      signingPayload,
      chainId: chainId,
    );
    return _rlpEncode([
      ...transactionFields,
      signature.v,
      signature.r,
      signature.s,
    ]);
  }

  Uint8List _hmacSha512(List<int> key, List<int> data) {
    final hmac = HMac(SHA512Digest(), 128)
      ..init(KeyParameter(Uint8List.fromList(key)));
    return hmac.process(Uint8List.fromList(data));
  }

  /// 获取压缩 secp256k1 公钥（33 字节），用于 BIP-32 非硬化子密钥派生。
  Uint8List _compressedPublicKey(Uint8List privateKey) {
    final params = ECCurve_secp256k1();
    final point = params.G * _bytesToBigInt(privateKey);
    if (point == null) {
      throw StateError('Failed to derive secp256k1 public key');
    }
    return point.getEncoded(true);
  }

  Uint8List _hexToBytes(String hex) {
    final normalized = hex.startsWith('0x') || hex.startsWith('0X')
        ? hex.substring(2)
        : hex;
    if (normalized.length.isOdd) {
      throw FormatException('Hex string must have an even length');
    }
    return Uint8List.fromList(HEX.decode(normalized));
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    if (bytes.isEmpty) return BigInt.zero;
    return BigInt.parse(HEX.encode(bytes), radix: 16);
  }

  Uint8List _bigIntToBytes(BigInt value, {int? length}) {
    if (value < BigInt.zero) {
      throw ArgumentError.value(value, 'value', 'Must not be negative');
    }
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = Uint8List.fromList(hex == '00' ? <int>[] : HEX.decode(hex));

    if (length == null) return bytes;
    if (bytes.length > length) {
      throw ArgumentError('Integer does not fit in $length bytes');
    }
    final padded = Uint8List(length);
    padded.setRange(length - bytes.length, length, bytes);
    return padded;
  }

  // ─── RLP Encoding / Decoding ─────────────────────────────────────────────

  dynamic _rlpDecode(Uint8List data) {
    final result = _rlpDecodeItem(data, 0);
    if (result.nextOffset != data.length) {
      throw FormatException('Unexpected trailing bytes in RLP payload');
    }
    return result.value;
  }

  _RlpResult _rlpDecodeItem(Uint8List data, int offset) {
    if (offset >= data.length) {
      throw FormatException('Unexpected end of RLP payload');
    }

    final prefix = data[offset];
    if (prefix < 0x80) {
      return _RlpResult(Uint8List.fromList([prefix]), offset + 1);
    }
    if (prefix <= 0xb7) {
      final length = prefix - 0x80;
      return _RlpResult(
        data.sublist(offset + 1, offset + 1 + length),
        offset + 1 + length,
      );
    }
    if (prefix <= 0xbf) {
      final lenBytes = prefix - 0xb7;
      final length = _readLength(data, offset + 1, lenBytes);
      return _RlpResult(
        data.sublist(offset + 1 + lenBytes, offset + 1 + lenBytes + length),
        offset + 1 + lenBytes + length,
      );
    }
    if (prefix <= 0xf7) {
      return _decodeRlpList(data, offset + 1, prefix - 0xc0);
    }

    final lenBytes = prefix - 0xf7;
    final length = _readLength(data, offset + 1, lenBytes);
    return _decodeRlpList(data, offset + 1 + lenBytes, length);
  }

  _RlpResult _decodeRlpList(Uint8List data, int start, int length) {
    final end = start + length;
    if (end > data.length) {
      throw FormatException('RLP list exceeds payload length');
    }

    final list = <dynamic>[];
    var pos = start;
    while (pos < end) {
      final item = _rlpDecodeItem(data, pos);
      list.add(item.value);
      pos = item.nextOffset;
    }
    if (pos != end) {
      throw FormatException('Invalid RLP list length');
    }
    return _RlpResult(list, end);
  }

  int _readLength(Uint8List data, int offset, int lenBytes) {
    if (offset + lenBytes > data.length) {
      throw FormatException('RLP length exceeds payload length');
    }
    var length = 0;
    for (var i = 0; i < lenBytes; i++) {
      length = (length << 8) | data[offset + i];
    }
    return length;
  }

  Uint8List _rlpEncode(dynamic input) {
    if (input is Uint8List) {
      if (input.length == 1 && input[0] < 0x80) return input;
      return Uint8List.fromList([
        ..._rlpEncodeLength(input.length, 0x80),
        ...input,
      ]);
    }
    if (input is List<int>) {
      return _rlpEncode(Uint8List.fromList(input));
    }
    if (input is List) {
      final encoded = input.map(_rlpEncode).toList();
      final totalLength = encoded.fold<int>(0, (sum, e) => sum + e.length);
      return Uint8List.fromList([
        ..._rlpEncodeLength(totalLength, 0xc0),
        ...encoded.expand((e) => e),
      ]);
    }
    if (input is BigInt) {
      if (input == BigInt.zero) return Uint8List.fromList([0x80]);
      return _rlpEncode(_bigIntToBytes(input));
    }
    if (input is int) {
      return _rlpEncode(BigInt.from(input));
    }
    if (input is String && input.isEmpty) {
      return Uint8List.fromList([0x80]);
    }
    throw ArgumentError('Unsupported RLP type: ${input.runtimeType}');
  }

  Uint8List _rlpEncodeLength(int length, int offset) {
    if (length < 56) return Uint8List.fromList([offset + length]);
    final lenBytes = _intToMinBytes(length);
    return Uint8List.fromList([offset + 55 + lenBytes.length, ...lenBytes]);
  }

  Uint8List _intToMinBytes(int value) {
    if (value == 0) return Uint8List(0);
    final bytes = <int>[];
    var v = value;
    while (v > 0) {
      bytes.insert(0, v & 0xff);
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }
}

class _RlpResult {
  const _RlpResult(this.value, this.nextOffset);

  final dynamic value;
  final int nextOffset;
}
