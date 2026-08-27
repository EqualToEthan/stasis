import 'dart:convert';
import 'dart:typed_data';

import 'package:coldwallet_watch/services/evm_rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// 拦截所有 HTTP 请求并返回预设响应的 mock client。
class _FakeClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  _FakeClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

http.StreamedResponse _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  return http.StreamedResponse(
    Stream.fromIterable([bytes]),
    statusCode,
    contentLength: bytes.length,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('EvmRpcService', () {
    test('getBalance parses hex result', () async {
      final client = _FakeClient((request) async {
        final body =
            jsonDecode(await request.finalize().bytesToString())
                as Map<String, dynamic>;
        expect(body['method'], 'eth_getBalance');
        expect(body['params'], ['0xabcd', 'latest']);
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x1'});
      });
      final service = EvmRpcService(client: client);
      final balance = await service.getBalance('https://rpc.test', '0xAbCd');
      expect(balance, BigInt.one);
    });

    test('getTokenBalance sends correct eth_call data', () async {
      final client = _FakeClient((request) async {
        final body =
            jsonDecode(await request.finalize().bytesToString())
                as Map<String, dynamic>;
        expect(body['method'], 'eth_call');
        final call = body['params'][0] as Map<String, dynamic>;
        expect(call['to'], '0xcontract');
        expect(
          call['data'],
          '0x70a08231000000000000000000000000deadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        );
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x2'});
      });
      final service = EvmRpcService(client: client);
      final balance = await service.getTokenBalance(
        'https://rpc.test',
        '0xDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEfDeAdBeEf',
        '0xContract',
      );
      expect(balance, BigInt.two);
    });

    test('getTokenSymbol decodes ABI string', () async {
      final client = _FakeClient((request) async {
        final body =
            jsonDecode(await request.finalize().bytesToString())
                as Map<String, dynamic>;
        expect(body['method'], 'eth_call');
        final call = body['params'][0] as Map<String, dynamic>;
        expect(call['data'], '0x95d89b41');
        // USDC: string "USDC"
        // offset 32, length 4, data "USDC" padded
        const symbolHex =
            '0000000000000000000000000000000000000000000000000000000000000020'
            '0000000000000000000000000000000000000000000000000000000000000004'
            '5553444300000000000000000000000000000000000000000000000000000000';
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': '0x$symbolHex',
        });
      });
      final service = EvmRpcService(client: client);
      final symbol = await service.getTokenSymbol('https://rpc.test', '0xusdc');
      expect(symbol, 'USDC');
    });

    test('getTokenSymbol decodes bytes32 symbol', () async {
      final client = _FakeClient((request) async {
        // MKR
        const symbolHex =
            '4d4b520000000000000000000000000000000000000000000000000000000000';
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': '0x$symbolHex',
        });
      });
      final service = EvmRpcService(client: client);
      final symbol = await service.getTokenSymbol('https://rpc.test', '0xmkr');
      expect(symbol, 'MKR');
    });

    test('getTokenDecimals parses uint8 result', () async {
      final client = _FakeClient((request) async {
        final call =
            (jsonDecode(await request.finalize().bytesToString())
                    as Map<String, dynamic>)['params'][0]
                as Map<String, dynamic>;
        expect(call['data'], '0x313ce567');
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x6'});
      });
      final service = EvmRpcService(client: client);
      final decimals = await service.getTokenDecimals(
        'https://rpc.test',
        '0xusdc',
      );
      expect(decimals, 6);
    });

    test('isErc20Readable returns true when both calls succeed', () async {
      final client = _FakeClient((request) async {
        final body =
            jsonDecode(await request.finalize().bytesToString())
                as Map<String, dynamic>;
        final data =
            (body['params'][0] as Map<String, dynamic>)['data'] as String;
        if (data == '0x313ce567') {
          return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x6'});
        }
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
      });
      final service = EvmRpcService(client: client);
      final readable = await service.isErc20Readable(
        'https://rpc.test',
        '0xtoken',
      );
      expect(readable, isTrue);
    });

    test('isErc20Readable returns false when decimals reverts', () async {
      final client = _FakeClient((request) async {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -32000, 'message': 'execution reverted'},
        });
      });
      final service = EvmRpcService(client: client);
      final readable = await service.isErc20Readable(
        'https://rpc.test',
        '0xtoken',
      );
      expect(readable, isFalse);
    });

    test('throws on HTTP error', () async {
      final client = _FakeClient(
        (request) async => _jsonResponse({}, statusCode: 500),
      );
      final service = EvmRpcService(client: client);
      expect(
        () => service.getBalance('https://rpc.test', '0xabc'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
