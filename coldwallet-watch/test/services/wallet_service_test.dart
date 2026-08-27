import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_watch/models/watch_wallet.dart';
import 'package:coldwallet_watch/services/storage_service.dart';
import 'package:coldwallet_watch/services/wallet_service.dart';

import '../support/fake_storage_service.dart';

void main() {
  group('WalletService current wallet', () {
    test('returns null when no wallets', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      final wallet = await service.getCurrentWallet();
      expect(wallet, isNull);
    });

    test(
      'returns first wallet and persists it when current id is unset',
      () async {
        final storage = FakeStorageService();
        final service = WalletService(storage);
        await service.addWallet(
          name: 'A',
          address: 'addr_test1abc',
          chainFamily: 'cardano',
          network: 'preview',
        );
        final wallet = await service.getCurrentWallet();
        expect(wallet, isNotNull);
        expect(wallet!.name, 'A');
        expect(await storage.getCurrentWalletId(), wallet.id);
      },
    );

    test('returns wallet matching persisted current id', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      await service.addWallet(
        name: 'A',
        address: 'addr_test1abc',
        chainFamily: 'cardano',
        network: 'preview',
      );
      await service.addWallet(
        name: 'B',
        address: 'addr_test1def',
        chainFamily: 'cardano',
        network: 'preview',
      );
      final wallets = await service.getWallets();
      final second = wallets[1];
      await service.setCurrentWallet(second.id);
      final current = await service.getCurrentWallet();
      expect(current!.name, 'B');
    });
  });

  group('WalletService.validateAddress', () {
    late WalletService service;

    setUp(() {
      service = WalletService(FakeStorageService());
    });

    test('accepts valid Cardano mainnet address', () {
      const addr =
          'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjc7';
      expect(service.validateAddress(addr, 'cardano'), isTrue);
    });

    test('accepts valid Cardano testnet address', () {
      const addr =
          'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq';
      expect(service.validateAddress(addr, 'cardano'), isTrue);
    });

    test('rejects short Cardano address', () {
      expect(service.validateAddress('addr_test1abc', 'cardano'), isFalse);
    });

    test('rejects non-Cardano prefix for cardano chain', () {
      expect(service.validateAddress('0xabcdef', 'cardano'), isFalse);
    });

    test('accepts valid EVM address', () {
      const addr = '0x505dfdb3ea595c2a206b8db63621a3a64126b9ee';
      expect(service.validateAddress(addr, 'evm'), isTrue);
    });

    test('accepts EVM address with uppercase hex', () {
      const addr = '0x505DFDB3EA595C2A206B8DB63621A3A64126B9EE';
      expect(service.validateAddress(addr, 'evm'), isTrue);
    });

    test('rejects EVM address with wrong length', () {
      expect(service.validateAddress('0x505dfdb3ea', 'evm'), isFalse);
    });

    test('rejects EVM address without 0x prefix', () {
      const addr = '505dfdb3ea595c2a206b8db63621a3a64126b9ee';
      expect(service.validateAddress(addr, 'evm'), isFalse);
    });

    test('rejects EVM address with non-hex characters', () {
      const addr = '0x505dfdb3ea595c2a206b8db63621a3a64126zzzz';
      expect(service.validateAddress(addr, 'evm'), isFalse);
    });

    test('rejects empty address', () {
      expect(service.validateAddress('', 'cardano'), isFalse);
      expect(service.validateAddress('', 'evm'), isFalse);
    });

    test('rejects unknown chain family', () {
      expect(service.validateAddress('anything', 'bitcoin'), isFalse);
    });
  });

  group('WalletService.detectChainFamily', () {
    late WalletService service;

    setUp(() {
      service = WalletService(FakeStorageService());
    });

    test('detects Cardano mainnet address', () {
      const addr =
          'addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq2ytjc7';
      expect(service.detectChainFamily(addr), 'cardano');
    });

    test('detects Cardano testnet address', () {
      const addr =
          'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq';
      expect(service.detectChainFamily(addr), 'cardano');
    });

    test('detects EVM address', () {
      const addr = '0x505dfdb3ea595c2a206b8db63621a3a64126b9ee';
      expect(service.detectChainFamily(addr), 'evm');
    });

    test('returns null for empty string', () {
      expect(service.detectChainFamily(''), isNull);
    });

    test('returns null for unrecognized format', () {
      expect(service.detectChainFamily('not-an-address'), isNull);
    });
  });

  group('WatchWallet model', () {
    test('create sets chainFamily and chainId', () {
      final wallet = WatchWallet.create(
        name: 'EVM Wallet',
        address: '0x505dfdb3ea595c2a206b8db63621a3a64126b9ee',
        chainFamily: 'evm',
        chainId: 'evm-97',
        network: 'preview',
      );
      expect(wallet.chainFamily, 'evm');
      expect(wallet.chainId, 'evm-97');
      expect(wallet.isEvm, isTrue);
      expect(wallet.isCardano, isFalse);
    });

    test(
      'fromJson backward compatible: missing chainFamily defaults to cardano',
      () {
        final json = {
          'id': '1',
          'name': 'Old Wallet',
          'address': 'addr_test1qz...',
          'network': 'preview',
          'createdAt': '2026-01-01T00:00:00.000',
        };
        final wallet = WatchWallet.fromJson(json);
        expect(wallet.chainFamily, 'cardano');
        expect(wallet.chainId, isNull);
      },
    );

    test('toJson includes chainFamily and chainId', () {
      final wallet = WatchWallet.create(
        name: 'EVM',
        address: '0x505dfdb3ea595c2a206b8db63621a3a64126b9ee',
        chainFamily: 'evm',
        chainId: 'evm-97',
        network: 'preview',
      );
      final json = wallet.toJson();
      expect(json['chainFamily'], 'evm');
      expect(json['chainId'], 'evm-97');
    });

    test('toJson omits chainId when null', () {
      final wallet = WatchWallet.create(
        name: 'ADA',
        address: 'addr_test1qz...',
        chainFamily: 'cardano',
        network: 'preview',
      );
      final json = wallet.toJson();
      expect(json.containsKey('chainId'), isFalse);
    });
  });

  group('WalletService.updateWallet', () {
    test('renames wallet via copyWith', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      final wallet = await service.addWallet(
        name: 'Original',
        address: 'addr_test1abc',
        chainFamily: 'cardano',
        network: 'preview',
      );
      await service.updateWallet(wallet.copyWith(name: 'Renamed'));
      final wallets = await service.getWallets();
      expect(wallets.length, 1);
      expect(wallets.first.name, 'Renamed');
      expect(wallets.first.id, wallet.id);
    });

    test('does nothing when wallet id not found', () async {
      final storage = FakeStorageService();
      final service = WalletService(storage);
      final ghost = WatchWallet(
        id: 'nonexistent',
        name: 'Ghost',
        address: 'addr_test1abc',
        chainFamily: 'cardano',
        network: 'preview',
        createdAt: DateTime.now(),
      );
      await service.updateWallet(ghost);
      final wallets = await service.getWallets();
      expect(wallets, isEmpty);
    });
  });
}
