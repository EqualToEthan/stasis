import 'dart:typed_data';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:cardano_dart_types/cardano_dart_types.dart';
import 'package:cardano_flutter_sdk/cardano_flutter_sdk.dart';

import '../models/wallet_info.dart';
import 'adapter_registry.dart';
import 'chain_registry.dart';
import 'secure_storage_service.dart';

/// 钱包服务（多钱包版）：助记词、地址派生、密钥管理
///
/// 支持最多 5 个钱包，每个钱包独立助记词和可选 BIP-39 密码短语，
/// 共享全局 PIN。网络由 AppConfig.isMainnet 全局控制。
class WalletService {
  static const int maxWallets = 5;

  final SecureStorageService _secureStorage = SecureStorageService();

  // ─── 助记词生成 ─────────────────────────────────────────────

  /// 生成新的 24 词助记词
  ///
  /// 使用 cardano_flutter_sdk 内置的安全随机源。
  List<String> generateMnemonic() {
    return WalletFactory.generateNewMnemonic(
      wordsCount: MnemonicsWordsCount.w24,
    );
  }

  /// 从骰子熵生成助记词
  ///
  /// [bits] 必须是 256 个布尔值（true=1, false=0），
  /// 对应 BIP-39 24 词助记词所需的 256 bits 熵。
  String mnemonicFromDiceBits(List<bool> bits) {
    if (bits.length != 256) {
      throw ArgumentError('需要恰好 256 个骰子结果');
    }
    final bytes = Uint8List(32);
    for (var i = 0; i < 256; i++) {
      if (bits[i]) {
        bytes[i ~/ 8] |= (1 << (7 - (i % 8)));
      }
    }
    return bip39.entropyToMnemonic(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  /// 校验助记词是否有效
  bool validateMnemonic(String mnemonic) {
    if (mnemonic.trim().isEmpty) return false;
    try {
      return bip39.validateMnemonic(mnemonic.trim());
    } catch (_) {
      return false;
    }
  }

  // ─── Cardano 链上操作 ───────────────────────────────────────

  /// 从助记词创建 HD 钱包
  ///
  /// [mnemonic] 12 或 24 个单词的助记词
  /// [passphrase] BIP-39 密码短语，默认空字符串（不使用）。
  ///   非空时通过 PBKDF2 将助记词+密码短语生成 64 字节种子再派生钱包，
  ///   相同的助记词 + 不同的密码短语会产生完全不同的地址。
  ///
  /// 网络由 [AppConfig.isMainnet] 全局控制，不接受参数覆盖。
  Future<CardanoWallet> createWallet(
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
    // BIP-39: mnemonic + passphrase → 64-byte seed → HD wallet
    final seed = bip39.mnemonicToSeed(mnemonic.trim(), passphrase: passphrase);
    final hdWallet = HdWallet.fromSeed(seed);
    return WalletFactory.fromHdWallet(network, hdWallet);
  }

  /// 派生第一个外部支付地址
  ///
  /// 使用 CIP-1852 路径 m/1852'/1815'/0'/0/0 派生。
  Future<String> deriveAddress(
    String mnemonic, {
    String passphrase = '',
  }) async {
    final wallet = await createWallet(mnemonic, passphrase: passphrase);
    final addrKit = await wallet.getPaymentAddressKit(addressIndex: 0);
    return addrKit.address.bech32Encoded;
  }

  /// 派生 stake address
  ///
  /// 使用 CIP-1852 路径 m/1852'/1815'/0'/2/0 派生。
  /// testnet 前缀为 stake_test，mainnet 前缀为 stake1。
  Future<String> deriveStakeAddress(
    String mnemonic, {
    String passphrase = '',
  }) async {
    final wallet = await createWallet(mnemonic, passphrase: passphrase);
    return wallet.stakeAddress.bech32Encoded;
  }

  // ─── 多链地址派生 ──────────────────────────────────────────

  /// 派生指定链的地址
  ///
  /// 通过 ChainRegistry 获取对应适配器，从同一助记词派生不同链的地址。
  Future<String> deriveAddressForChain(
    String mnemonic,
    ChainConfig config, {
    String passphrase = '',
  }) async {
    final adapter = AdapterRegistry.adapterFor(config.chainFamily);
    return adapter.deriveAddress(mnemonic, config, passphrase: passphrase);
  }

  /// 获取当前钱包在所有链上的地址
  ///
  /// 返回 `Map<chainId, address>`，遍历 ChainRegistry 中所有配置。
  Future<Map<String, String>> deriveAllAddresses(
    String mnemonic, {
    String passphrase = '',
  }) async {
    final result = <String, String>{};
    for (final config in ChainRegistry.allConfigs()) {
      result[config.chainId] = await deriveAddressForChain(
        mnemonic,
        config,
        passphrase: passphrase,
      );
    }
    return result;
  }

  // ─── 钱包列表管理 ───────────────────────────────────────────

  Future<List<WalletInfo>> getWallets() async {
    return await _secureStorage.loadWalletList();
  }

  Future<bool> hasWallets() async {
    final wallets = await getWallets();
    return wallets.isNotEmpty;
  }

  Future<bool> canAddWallet() async {
    final wallets = await getWallets();
    return wallets.length < maxWallets;
  }

  // ─── 当前钱包 ───────────────────────────────────────────────

  Future<WalletInfo?> getCurrentWallet() async {
    final wallets = await getWallets();
    if (wallets.isEmpty) return null;
    final currentId = await _secureStorage.getCurrentWalletId();
    return wallets.where((w) => w.id == currentId).firstOrNull ?? wallets.first;
  }

  Future<String?> loadCurrentMnemonic() async {
    final wallet = await getCurrentWallet();
    if (wallet == null) return null;
    return await _secureStorage.readMnemonic(wallet.id);
  }

  Future<void> switchWallet(String walletId) async {
    await _secureStorage.setCurrentWalletId(walletId);
  }

  // ─── 创建/导入钱包 ──────────────────────────────────────────

  /// 添加新钱包并设为当前钱包
  ///
  /// 保存助记词到安全存储，更新钱包列表和当前选中钱包。
  /// [passphrase] 可选 BIP-39 密码短语，非空时保存到安全存储。
  /// 返回新创建的 WalletInfo。
  Future<WalletInfo> addWallet({
    required String name,
    required String mnemonic,
    String passphrase = '',
  }) async {
    final wallets = await getWallets();
    if (wallets.length >= maxWallets) {
      throw StateError('钱包数量已达上限（$maxWallets）');
    }

    final info = WalletInfo.create(name: name);
    wallets.add(info);

    await _secureStorage.saveWalletList(wallets);
    await _secureStorage.saveMnemonic(info.id, mnemonic);
    if (passphrase.isNotEmpty) {
      await _secureStorage.savePassphrase(info.id, passphrase);
    }
    await _secureStorage.setCurrentWalletId(info.id);

    return info;
  }

  // ─── 删除钱包 ───────────────────────────────────────────────

  /// 删除钱包
  ///
  /// 删除助记词和元数据，如果删除的是当前钱包则自动切换。
  Future<void> deleteWallet(String walletId) async {
    final wallets = await getWallets();
    wallets.removeWhere((w) => w.id == walletId);

    await _secureStorage.deleteMnemonic(walletId);
    await _secureStorage.deletePassphrase(walletId);
    await _secureStorage.saveWalletList(wallets);

    // 如果删除的是当前钱包，切换到第一个（或清空 currentId）
    final currentId = await _secureStorage.getCurrentWalletId();
    if (currentId == walletId) {
      if (wallets.isNotEmpty) {
        await _secureStorage.setCurrentWalletId(wallets.first.id);
      } else {
        await _secureStorage.setCurrentWalletId('');
      }
    }
  }

  // ─── 重命名 ───────────────────────────────────────────────

  /// 重命名钱包（仅修改 WalletInfo 元数据，不触碰助记词）
  Future<void> renameWallet(String walletId, String newName) async {
    final wallets = await getWallets();
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index < 0) throw StateError('钱包不存在');
    wallets[index] = wallets[index].copyWith(name: newName);
    await _secureStorage.saveWalletList(wallets);
  }

  // ─── 重置所有 ───────────────────────────────────────────────

  /// 清除所有钱包数据（PIN 保留）
  Future<void> resetAllWallets() async {
    final wallets = await getWallets();
    for (final w in wallets) {
      await _secureStorage.deleteMnemonic(w.id);
      await _secureStorage.deletePassphrase(w.id);
    }
    await _secureStorage.saveWalletList([]);
    await _secureStorage.setCurrentWalletId('');
  }

  /// 清除全部存储（含 PIN）
  Future<void> factoryReset() async {
    await _secureStorage.clearAll();
  }

  // ─── PIN（全局） ────────────────────────────────────────────

  Future<void> savePin(String pin) async {
    await _secureStorage.savePin(pin);
  }

  Future<bool> verifyPin(String pin) async {
    return await _secureStorage.verifyPin(pin);
  }

  Future<bool> hasPin() async {
    return await _secureStorage.hasPin();
  }

  // ─── 密码短语（BIP-39 passphrase） ─────────────────────────

  /// 保存指定钱包的 BIP-39 密码短语
  Future<void> savePassphrase(String walletId, String passphrase) async {
    await _secureStorage.savePassphrase(walletId, passphrase);
  }

  /// 读取当前钱包的密码短语，未设置时返回空字符串
  Future<String> loadCurrentPassphrase() async {
    final wallet = await getCurrentWallet();
    if (wallet == null) return '';
    return await _secureStorage.readPassphrase(wallet.id) ?? '';
  }
}
