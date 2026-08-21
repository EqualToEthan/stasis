import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Blockfrost 网络端点配置
///
/// 包含 mainnet、preprod、preview 三个网络的 API 基础 URL。
class BlockfrostEndpoint {
  static const Map<String, String> baseUrls = {
    'mainnet': 'https://cardano-mainnet.blockfrost.io/api/v0',
    'preprod': 'https://cardano-preprod.blockfrost.io/api/v0',
    'preview': 'https://cardano-preview.blockfrost.io/api/v0',
  };
}

/// Blockfrost API 服务
///
/// 封装对 Blockfrost REST API 的调用，
/// 提供 UTxO 查询、地址余额、最新区块、协议参数和交易提交功能。
class BlockfrostService {
  final String _apiKey;
  final String _network;
  final http.Client _client;

  BlockfrostService({
    required String apiKey,
    required String network,
    http.Client? client,
  }) : _apiKey = apiKey,
       _network = network,
       _client = client ?? http.Client();

  String get _baseUrl =>
      BlockfrostEndpoint.baseUrls[_network] ??
      BlockfrostEndpoint.baseUrls['preview']!;

  Map<String, String> get _headers => {
    'project_id': _apiKey,
    'Content-Type': 'application/json',
  };

  /// 查询地址的所有 UTxO
  Future<List<Map<String, dynamic>>> getAddressUtxos(String address) async {
    final url = Uri.parse('$_baseUrl/addresses/$address/utxos');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// 查询地址的资产余额
  ///
  /// 若地址在链上从未出现过（Blockfrost 返回 404），
  /// 返回空余额对象 `{"amount": []}` 而非抛异常。
  Future<Map<String, dynamic>> getAddressBalance(String address) async {
    final url = Uri.parse('$_baseUrl/addresses/$address');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode == 404) {
      // 地址尚未在链上出现过，返回空余额
      return {'amount': <dynamic>[]};
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 获取最新区块信息（用于获取当前 slot）
  Future<Map<String, dynamic>> getLatestBlock() async {
    final url = Uri.parse('$_baseUrl/blocks/latest');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 获取当前协议参数（手续费系数、最小 UTxO 等）
  Future<Map<String, dynamic>> getProtocolParams() async {
    final url = Uri.parse('$_baseUrl/epochs/latest/parameters');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 提交已签名交易到链上
  ///
  /// [txBytes] 已签名交易的 CBOR 字节数组
  /// 返回交易哈希
  Future<String> submitTx(Uint8List txBytes) async {
    final url = Uri.parse('$_baseUrl/tx/submit');
    final response = await _client.post(
      url,
      headers: {'project_id': _apiKey, 'Content-Type': 'application/cbor'},
      body: txBytes,
    );
    if (response.statusCode != 200) {
      throw Exception('Submit failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as String;
  }

  // ─── 质押相关查询 ───────────────────────────────────

  /// 查询 stake pool 信息
  ///
  /// [poolId] Bech32 格式的 pool ID（如 pool1abc...）
  /// 返回包含 pool 详细信息的 JSON（pledge、margin、retiring 等）
  Future<Map<String, dynamic>> getPoolInfo(String poolId) async {
    final url = Uri.parse('$_baseUrl/pools/$poolId');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode == 404) {
      throw Exception('Pool not found: $poolId');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 检查 stake pool 是否已退役
  ///
  /// 返回 true 表示 pool 正在或已经退役（retiring epoch 不为 null）。
  Future<bool> isPoolRetired(String poolId) async {
    final info = await getPoolInfo(poolId);
    return info['retiring'] != null;
  }

  /// 查询 stake account 信息
  ///
  /// [stakeAddress] Bech32 格式的 stake address
  /// 返回 JSON 包含：
  /// - `active` (bool): stake key 是否已注册
  /// - `pool_id` (String?): 当前委托的 pool
  /// - `withdrawable_amount` (String): 可提取的奖励 lovelace
  /// - `controlled_amount` (String): 控制的总 ADA lovelace
  Future<Map<String, dynamic>> getStakeAccountInfo(String stakeAddress) async {
    final url = Uri.parse('$_baseUrl/accounts/$stakeAddress');
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode == 404) {
      // stake key 未注册，返回默认未激活状态
      return {
        'active': false,
        'pool_id': null,
        'withdrawable_amount': '0',
        'controlled_amount': '0',
      };
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Blockfrost error: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
