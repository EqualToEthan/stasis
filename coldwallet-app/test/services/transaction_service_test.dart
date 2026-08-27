import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/transaction_service.dart';
import 'package:coldwallet_app/services/wallet_service.dart';
import 'package:coldwallet_protocol/coldwallet_protocol.dart';

Matcher get _throwsWalletMismatch => throwsA(
  isA<WalletMismatchException>().having(
    (e) => e.message,
    'message',
    contains('未签名交易与当前钱包不匹配'),
  ),
);

Matcher get _throwsNetworkMismatch => throwsA(
  isA<NetworkMismatchException>().having(
    (e) => e.message,
    'message',
    contains('两端网络配置不匹配'),
  ),
);

class _FakeWalletService extends WalletService {
  final String _mnemonic;
  final String _passphrase;

  _FakeWalletService(this._mnemonic, {String passphrase = ''})
    : _passphrase = passphrase;

  @override
  Future<String?> loadCurrentMnemonic() async => _mnemonic;

  @override
  Future<String> loadCurrentPassphrase() async => _passphrase;
}

void main() {
  // 每个测试前初始化为测试网，每个测试后重置回测试网
  setUp(() => AppConfig.isMainnet = false);
  tearDown(() => AppConfig.isMainnet = false);

  group('TransactionService', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';

    test(
      'throws friendly error when EVM unsigned tx fromAddress does not match current wallet',
      () async {
        final walletService = _FakeWalletService(mnemonic);
        final service = TransactionService(walletService);

        final rawJson =
            '{"version":1,"type":"unsigned-tx",'
            '"chainId":"evm-11155111","rawTxHex":"0xabcdef",'
            '"summary":{"fromAddress":"0x0000000000000000000000000000000000000001",'
            '"toAddress":"0x0000000000000000000000000000000000000002",'
            '"value":"1000","fee":"21000","nonce":1}}';

        expect(() => service.signForChain(rawJson), _throwsWalletMismatch);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'throws friendly error when EVM fromAddress differs only in checksum',
      () async {
        final walletService = _FakeWalletService(mnemonic);
        final service = TransactionService(walletService);

        // 派生地址为 0x9858EfFD232b4033E47d90003D41EC34EcaEda94；
        // 改成仅最后一位不同，且全小写，验证大小写不敏感比较不会误判。
        final rawJson =
            '{"version":1,"type":"unsigned-tx",'
            '"chainId":"evm-11155111","rawTxHex":"0xabcdef",'
            '"summary":{"fromAddress":"0x9858effd232b4033e47d90003d41ec34ecaeda93",'
            '"toAddress":"0x0000000000000000000000000000000000000002",'
            '"value":"1000","fee":"21000","nonce":1}}';

        expect(() => service.signForChain(rawJson), _throwsWalletMismatch);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'throws friendly error when Cardano unsigned tx fromAddress does not match current wallet',
      () async {
        final walletService = _FakeWalletService(mnemonic);
        final service = TransactionService(walletService);

        final rawJson =
            '{"version":1,"type":"unsigned-tx",'
            '"network":"preview","txCbor":"aabb",'
            '"summary":{"fromAddress":"addr_test1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9",'
            '"toAddress":"addr_test1vp2fg770ddmqxxkxxatwg4r0lw5y8spmmnhzlghm6rrwtjxu0rr7",'
            '"assets":[{"unit":"lovelace","quantity":"1000000"}],"fee":"200000"}}';

        expect(() => service.signForChain(rawJson), _throwsWalletMismatch);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'throws NetworkMismatchException when testnet app receives mainnet export',
      () async {
        final walletService = _FakeWalletService(mnemonic);
        final service = TransactionService(walletService);

        // AppConfig.isMainnet = false (default), but ColdExport.network = 'mainnet'
        final rawJson =
            '{"version":1,"type":"unsigned-tx",'
            '"network":"mainnet","txCbor":"aabb",'
            '"summary":{"fromAddress":"addr1dummy",'
            '"toAddress":"addr1dummy2",'
            '"assets":[{"unit":"lovelace","quantity":"1000000"}],"fee":"200000"}}';

        expect(() => service.signForChain(rawJson), _throwsNetworkMismatch);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'throws NetworkMismatchException when mainnet app receives testnet export',
      () async {
        AppConfig.isMainnet = true;
        final walletService = _FakeWalletService(mnemonic);
        final service = TransactionService(walletService);

        // AppConfig.isMainnet = true, but ColdExport.network = 'preview'
        final rawJson =
            '{"version":1,"type":"unsigned-tx",'
            '"network":"preview","txCbor":"aabb",'
            '"summary":{"fromAddress":"addr_test1dummy",'
            '"toAddress":"addr_test1dummy2",'
            '"assets":[{"unit":"lovelace","quantity":"1000000"}],"fee":"200000"}}';

        expect(() => service.signForChain(rawJson), _throwsNetworkMismatch);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
