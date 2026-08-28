import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// EVM JSON-RPC 服务
///
/// 基于现有 `http` 依赖封装的极简 JSON-RPC 客户端，仅支持本次需要的
/// `eth_getBalance` 和 `eth_call`，不引入 `web3dart`。
///
/// 所有请求统一 15 秒超时：端点挂死（连接后无响应）时快速失败，
/// 避免单链查询卡死整个余额加载（见 ADR-0008）。
class EvmRpcService {
  final http.Client _client;

  EvmRpcService({http.Client? client}) : _client = client ?? http.Client();

  /// 单次 RPC 请求的超时时长。
  static const _requestTimeout = Duration(seconds: 15);

  /// ERC-20 函数选择器（keccak256 前 4 字节）。
  static const _selectorBalanceOf = '0x70a08231';
  static const _selectorSymbol = '0x95d89b41';
  static const _selectorDecimals = '0x313ce567';

  /// 查询地址原生代币余额（wei）。
  Future<BigInt> getBalance(String rpcUrl, String address) async {
    final result = await _call(rpcUrl, 'eth_getBalance', [
      _toChecksummedAddress(address),
      'latest',
    ]);
    return _hexToBigInt(result as String);
  }

  /// 查询地址在指定 ERC-20 合约下的余额（最小单位）。
  Future<BigInt> getTokenBalance(
    String rpcUrl,
    String walletAddress,
    String contractAddress,
  ) async {
    final data = _selectorBalanceOf + _encodeAddress(walletAddress);
    final result = await _ethCall(rpcUrl, contractAddress, data);
    return _hexToBigInt(result);
  }

  /// 读取 ERC-20 合约的 symbol。
  ///
  /// 兼容返回 `string` 和 `bytes32` 的合约（如 MKR）。
  Future<String> getTokenSymbol(String rpcUrl, String contractAddress) async {
    final data = _selectorSymbol;
    final result = await _ethCall(rpcUrl, contractAddress, data);
    return _decodeStringOrBytes32(result);
  }

  /// 读取 ERC-20 合约的 decimals。
  Future<int> getTokenDecimals(String rpcUrl, String contractAddress) async {
    final data = _selectorDecimals;
    final result = await _ethCall(rpcUrl, contractAddress, data);
    return _hexToBigInt(result).toInt();
  }

  /// 校验合约是否支持 ERC-20 基本元数据读取。
  ///
  /// 同时调用 `decimals()` 和 `symbol()`，任一失败即认为非标准 ERC-20。
  Future<bool> isErc20Readable(String rpcUrl, String contractAddress) async {
    try {
      await Future.wait([
        getTokenDecimals(rpcUrl, contractAddress),
        getTokenSymbol(rpcUrl, contractAddress),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 发起通用 JSON-RPC 调用。
  Future<dynamic> _call(
    String rpcUrl,
    String method,
    List<dynamic> params,
  ) async {
    final payload = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });
    final response = await _client
        .post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('RPC HTTP ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body case {'error': {'message': final String msg, 'code': _}}) {
      throw Exception('RPC error: $msg');
    }

    if (!body.containsKey('result')) {
      throw Exception('RPC response missing result: ${response.body}');
    }

    return body['result'];
  }

  /// 对指定合约发起 `eth_call`。
  Future<String> _ethCall(
    String rpcUrl,
    String contractAddress,
    String data,
  ) async {
    final result = await _call(rpcUrl, 'eth_call', [
      {'to': _toChecksummedAddress(contractAddress), 'data': data},
      'latest',
    ]);
    return result as String;
  }

  /// 把地址统一转为小写并保留 0x 前缀（RPC 接受即可，不强制 EIP-55 校验和）。
  static String _toChecksummedAddress(String address) {
    if (!address.startsWith('0x')) {
      throw ArgumentError('EVM address must start with 0x: $address');
    }
    return address.toLowerCase();
  }

  /// 把地址编码为 32 字节 ABI 参数（左填充 0）。
  static String _encodeAddress(String address) {
    final clean = address.substring(2).toLowerCase();
    if (clean.length != 40) {
      throw ArgumentError('Invalid EVM address length: $address');
    }
    return clean.padLeft(64, '0');
  }

  /// 把 0x 前缀的 hex 字符串解析为 BigInt。
  static BigInt _hexToBigInt(String hex) {
    if (hex == '0x') return BigInt.zero;
    return BigInt.parse(_strip0x(hex), radix: 16);
  }

  /// 去掉 0x 前缀。
  static String _strip0x(String hex) {
    return hex.startsWith('0x') ? hex.substring(2) : hex;
  }

  /// 解码 ABI 编码的 string 或 bytes32。
  static String _decodeStringOrBytes32(String hex) {
    final clean = _strip0x(hex);
    if (clean == '0') return '';

    // bytes32：固定 32 字节，直接解码并去掉尾部 0。
    if (clean.length == 64) {
      final bytes = _hexToBytes(clean);
      final trimmed = _trimTrailingZeros(bytes);
      return utf8.decode(trimmed, allowMalformed: true);
    }

    // ABI string：offset(32) + length(32) + data(padded)。
    if (clean.length >= 128) {
      final offset = _hexToBigInt('0x${clean.substring(0, 64)}').toInt();
      if (offset == 32) {
        final length = _hexToBigInt('0x${clean.substring(64, 128)}').toInt();
        final dataStart = 128;
        final dataEnd = dataStart + length * 2;
        if (dataEnd <= clean.length) {
          final bytes = _hexToBytes(clean.substring(dataStart, dataEnd));
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
    }

    throw FormatException('Unable to decode symbol response: $hex');
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = _strip0x(hex);
    if (clean.length % 2 != 0) {
      throw FormatException('Invalid hex string length: $hex');
    }
    final bytes = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  static Uint8List _trimTrailingZeros(Uint8List bytes) {
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    return Uint8List.sublistView(bytes, 0, end);
  }
}
