import 'dart:async';
import 'dart:convert';

import 'package:coldwallet_watch/services/evm_rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// EvmRpcService 超时行为测试。
///
/// 端点挂死（连接后永不响应）时，调用必须在超时时间内失败，
/// 而非无限挂起（见 ADR-0008 缺陷 D1）。
void main() {
  group('EvmRpcService timeout', () {
    test(
      'getBalance throws TimeoutException when endpoint hangs',
      () async {
        // 模拟挂死端点：收到请求后永不返回响应
        final rpc = EvmRpcService(
          client: MockClient((_) => Completer<http.Response>().future),
        );

        await expectLater(
          rpc.getBalance('https://hanging.example.com', '0xAbC'),
          throwsA(isA<TimeoutException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'getTokenBalance throws TimeoutException when endpoint hangs',
      () async {
        final rpc = EvmRpcService(
          client: MockClient((_) => Completer<http.Response>().future),
        );

        await expectLater(
          rpc.getTokenBalance(
            'https://hanging.example.com',
            '0xAbC0000000000000000000000000000000000000',
            '0xDef0000000000000000000000000000000000000',
          ),
          throwsA(isA<TimeoutException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('normal response is unaffected by timeout wrapper', () async {
      final rpc = EvmRpcService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x1'}),
            200,
          ),
        ),
      );

      final balance = await rpc.getBalance('https://ok.example.com', '0xAbC');
      expect(balance, BigInt.one);
    });
  });
}
