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
  Future<Map<String, dynamic>> getAddressBalance(String address) async {
    final url = Uri.parse('$_baseUrl/addresses/$address');
    final response = await _client.get(url, headers: _headers);
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
}
