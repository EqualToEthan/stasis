import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/wallet_info.dart';
import '../services/chain_registry.dart';
import '../services/wallet_service.dart';
import 'dice_entropy_screen.dart';

/// 钱包管理页面
///
/// 展示所有钱包列表，支持：查看详情（多链地址 + Cardano Stake Address + 助记词）、
/// 每个地址行的二维码导出（Cardano 合并 QR，其他链单地址 QR）、重命名钱包、
/// 删除钱包、新增钱包（生成/掷骰子/导入）。首次进入时引导创建第一个钱包。
/// 助记词显示受 PIN 保护：有 PIN 时需验证通过才能查看，折叠后重置。
class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final WalletService _walletService = WalletService();
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();

  List<WalletInfo> _wallets = [];
  bool _isLoading = true;
  bool _hasPin = false;

  // 当前正在查看详情的钱包
  String? _expandedWalletId;
  Map<String, String>? _expandedAddresses;
  String? _expandedMnemonic;
  String? _expandedStakeAddress;
  bool _mnemonicUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final wallets = await _walletService.getWallets();
    final hasPin = await _walletService.hasPin();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _hasPin = hasPin;
      _isLoading = false;
      _expandedWalletId = null;
      _expandedAddresses = null;
      _expandedMnemonic = null;
      _expandedStakeAddress = null;
      _mnemonicUnlocked = false;
    });
  }

  Future<void> _expandWallet(WalletInfo wallet) async {
    if (_expandedWalletId == wallet.id) {
      setState(() {
        _expandedWalletId = null;
        _expandedAddresses = null;
        _expandedMnemonic = null;
        _expandedStakeAddress = null;
        _mnemonicUnlocked = false;
      });
      return;
    }
    // 临时切换以获取该钱包的信息
    final prevWallet = await _walletService.getCurrentWallet();
    await _walletService.switchWallet(wallet.id);
    final m = await _walletService.loadCurrentMnemonic();
    final passphrase = await _walletService.loadCurrentPassphrase();
    Map<String, String> allAddresses = {};
    if (m != null) {
      allAddresses = await _walletService.deriveAllAddresses(
        m,
        passphrase: passphrase,
      );
    }
    // Cardano 链可用时派生 stake address
    String? stakeAddress;
    final hasCardano = ChainRegistry.allConfigs().any(
      (c) => c.chainFamily == 'cardano' && allAddresses[c.chainId] != null,
    );
    if (hasCardano && m != null) {
      try {
        stakeAddress = await _walletService.deriveStakeAddress(
          m,
          passphrase: passphrase,
        );
      } catch (_) {}
    }
    // 恢复之前选中的钱包
    if (prevWallet != null) {
      await _walletService.switchWallet(prevWallet.id);
    }
    if (!mounted) return;
    setState(() {
      _expandedWalletId = wallet.id;
      _expandedAddresses = allAddresses;
      _expandedMnemonic = m;
      _expandedStakeAddress = stakeAddress;
      _mnemonicUnlocked = false;
    });
  }

  // ─── 新增钱包流程 ──────────────────────────────────────────

  void _showAddWalletSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '添加新钱包',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('生成新助记词'),
              subtitle: const Text('SDK 随机生成 24 词助记词'),
              onTap: () {
                Navigator.pop(ctx);
                _createWithGeneratedMnemonic();
              },
            ),
            ListTile(
              leading: const Icon(Icons.casino),
              title: const Text('掷骰子生成'),
              subtitle: const Text('使用物理骰子产生真随机熵'),
              onTap: () {
                Navigator.pop(ctx);
                _createWithDiceEntropy();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入已有助记词'),
              subtitle: const Text('输入 12 或 24 个单词'),
              onTap: () {
                Navigator.pop(ctx);
                _showImportForm();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _createWithGeneratedMnemonic() {
    final mnemonicWords = _walletService.generateMnemonic();
    final mnemonic = mnemonicWords.join(' ');
    _showNameAndConfirmDialog(mnemonic, isNew: true);
  }

  void _createWithDiceEntropy() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const DiceEntropyScreen()),
    );
    if (result != null && mounted) {
      _showNameAndConfirmDialog(result, isNew: true);
    }
  }

  bool _showingImportForm = false;

  void _showImportForm() {
    _mnemonicController.clear();
    _passphraseController.clear();
    setState(() => _showingImportForm = true);
  }

  Future<void> _importMnemonic() async {
    final mnemonic = _mnemonicController.text.trim();
    if (!_walletService.validateMnemonic(mnemonic)) {
      _showError('助记词无效，请检查拼写和词数');
      return;
    }
    final passphrase = _passphraseController.text;
    setState(() => _showingImportForm = false);
    _showNameAndConfirmDialog(mnemonic, isNew: false, passphrase: passphrase);
  }

  /// 显示命名对话框，然后根据 [isNew] 决定后续流程：
  ///
  /// - isNew=true（新建/掷骰子）：密码短语对话框 → 助记词确认 → PIN
  /// - isNew=false（导入）：跳过密码短语（已在导入表单收集）→ 助记词确认 → PIN
  void _showNameAndConfirmDialog(
    String mnemonic, {
    required bool isNew,
    String passphrase = '',
  }) {
    final nameController = TextEditingController(
      text: '钱包 ${_wallets.length + 1}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('设置钱包名称'),
        content: TextField(
          controller: nameController,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '钱包名称',
            hintText: '例如：我的主钱包',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                _showError('请输入钱包名称');
                return;
              }
              Navigator.pop(ctx);
              if (isNew) {
                // 新建/掷骰子流程：密码短语尚未输入，显示密码短语对话框
                _showPassphraseDialog(mnemonic, name: name, isNew: isNew);
              } else {
                // 导入流程：密码短语已在导入表单中输入，直接进入助记词确认
                _showMnemonicConfirm(
                  mnemonic,
                  name: name,
                  isNew: isNew,
                  passphrase: passphrase,
                );
              }
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 显示 BIP-39 密码短语输入对话框
  ///
  /// 可选步骤：用户可留空跳过。设置后相同助记词会产生完全不同的地址，
  /// 必须在助记词备份界面提醒用户一并记录。
  void _showPassphraseDialog(
    String mnemonic, {
    required String name,
    required bool isNew,
    String initialPassphrase = '',
  }) {
    final passphraseCtrl = TextEditingController(text: initialPassphrase);
    final confirmCtrl = TextEditingController(text: initialPassphrase);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('BIP-39 密码短语（可选）'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '密码短语与助记词共同决定钱包地址。设置后，相同的助记词会产生完全不同的地址。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '请务必将密码短语与助记词一起抄写备份，遗忘后无法恢复。',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passphraseCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码短语',
                  hintText: '留空表示不使用',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认密码短语',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final pp = passphraseCtrl.text;
              final confirm = confirmCtrl.text;
              if (pp != confirm) {
                _showError('两次输入的密码短语不一致');
                return;
              }
              Navigator.pop(ctx);
              _showMnemonicConfirm(
                mnemonic,
                name: name,
                isNew: isNew,
                passphrase: pp,
              );
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showMnemonicConfirm(
    String mnemonic, {
    required String name,
    required bool isNew,
    String passphrase = '',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? '新助记词 — 请备份' : '确认助记词'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '请妥善抄写在纸上，切勿截图或拍照：',
                style: TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 12),
              SelectableText(
                mnemonic,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (passphrase.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已设置密码短语，请务必一并记住！\n遗忘后无法恢复钱包。',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPinDialog(mnemonic, name: name, passphrase: passphrase);
            },
            child: const Text('已备份，继续'),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(
    String mnemonic, {
    required String name,
    String passphrase = '',
  }) {
    // 如果已有 PIN，不需要再次设置
    if (_hasPin) {
      _saveWallet(mnemonic, name: name, passphrase: passphrase);
      return;
    }

    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('设置 PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PIN 为全局使用，解锁 App 后可操作所有钱包'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '6 位 PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认 PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final pin = pinController.text;
              final confirm = confirmController.text;
              if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                _showError('PIN 必须是 6 位数字');
                return;
              }
              if (pin != confirm) {
                _showError('两次输入的 PIN 不一致');
                return;
              }
              Navigator.pop(ctx);
              await _walletService.savePin(pin);
              await _saveWallet(mnemonic, name: name, passphrase: passphrase);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWallet(
    String mnemonic, {
    required String name,
    String passphrase = '',
  }) async {
    try {
      await _walletService.addWallet(
        name: name,
        mnemonic: mnemonic,
        passphrase: passphrase,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('钱包「$name」已创建'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadState();
    } catch (e) {
      _showError('创建失败: $e');
    }
  }

  // ─── 删除钱包 ──────────────────────────────────────────────

  Future<void> _deleteWallet(WalletInfo wallet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${wallet.name}」'),
        content: const Text('确定要删除此钱包吗？助记词将被永久清除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _walletService.deleteWallet(wallet.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('钱包「${wallet.name}」已删除')));
      }
      await _loadState();
    }
  }

  /// 显示重命名对话框
  ///
  /// 预填当前名称，校验非空、不超 20 字符、不与其它钱包重名后保存。
  void _showRenameDialog(WalletInfo wallet) {
    final nameController = TextEditingController(text: wallet.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名钱包'),
        content: TextField(
          controller: nameController,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(labelText: '钱包名称', counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                _showError('请输入钱包名称');
                return;
              }
              if (_wallets.any((w) => w.id != wallet.id && w.name == newName)) {
                _showError('该名称已存在');
                return;
              }
              Navigator.pop(ctx);
              await _walletService.renameWallet(wallet.id, newName);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('已重命名为「$newName」')));
              }
              await _loadState();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _truncate(String value, {int head = 12, int tail = 12}) {
    if (value.length <= head + tail + 3) return value;
    return '${value.substring(0, head)}...${value.substring(value.length - tail)}';
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 已复制')));
  }

  /// 显示 PIN 验证对话框，验证通过后解锁助记词显示。
  void _showPinVerifyDialog() {
    final pinController = TextEditingController();
    bool obscurePin = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('验证 PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: obscurePin,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              labelText: '6 位 PIN',
              counterText: '',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePin ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setDialogState(() => obscurePin = !obscurePin);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                  _showError('请输入 6 位数字 PIN');
                  return;
                }
                final valid = await _walletService.verifyPin(pin);
                if (!valid) {
                  HapticFeedback.mediumImpact();
                  _showError('PIN 错误');
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() => _mnemonicUnlocked = true);
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI 构建 ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('钱包管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty && !_showingImportForm
          ? _buildEmptyState()
          : _buildWalletList(),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有钱包',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '选择一种方式创建你的第一个钱包',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _createWithGeneratedMnemonic,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('生成新助记词'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createWithDiceEntropy,
            icon: const Icon(Icons.casino),
            label: const Text('掷骰子生成（真随机）'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showImportForm,
            icon: const Icon(Icons.download),
            label: const Text('导入已有助记词'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          if (_showingImportForm) ...[
            const SizedBox(height: 24),
            _buildImportForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showingImportForm) ...[
            _buildImportForm(),
            const SizedBox(height: 16),
          ],
          for (final wallet in _wallets) ...[
            _buildWalletCard(wallet),
            const SizedBox(height: 12),
          ],
          if (_wallets.length < WalletService.maxWallets) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showAddWalletSheet,
              icon: const Icon(Icons.add),
              label: const Text('添加新钱包'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '已达钱包数量上限（${WalletService.maxWallets}个），不能再新增',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletCard(WalletInfo wallet) {
    final isExpanded = _expandedWalletId == wallet.id;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text(wallet.name),
            subtitle: Text(
              wallet.createdAt.toLocal().toString().split('.').first,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: '重命名',
                  onPressed: () => _showRenameDialog(wallet),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _deleteWallet(wallet),
                ),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: () => _expandWallet(wallet),
          ),
          if (isExpanded && _expandedAddresses != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('多链地址', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final config in ChainRegistry.allConfigs())
                    if (_expandedAddresses![config.chainId] != null) ...[
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(config.name),
                          subtitle: Text(
                            _truncate(_expandedAddresses![config.chainId]!),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _showAddressQr(
                                  _expandedAddresses![config.chainId]!,
                                  config,
                                ),
                                icon: const Icon(Icons.qr_code_2, size: 16),
                                tooltip: '显示二维码',
                              ),
                              IconButton(
                                onPressed: () => _copyText(
                                  _expandedAddresses![config.chainId]!,
                                  '${config.name} 地址',
                                ),
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: '复制地址',
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Cardano 链额外展示 Stake Address
                      if (config.chainFamily == 'cardano' &&
                          _expandedStakeAddress != null)
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: const Icon(Icons.key, size: 20),
                            title: const Text('Stake Address'),
                            subtitle: Text(
                              _truncate(_expandedStakeAddress!),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                            trailing: IconButton(
                              onPressed: () => _copyText(
                                _expandedStakeAddress!,
                                'Stake Address',
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: '复制 stake address',
                            ),
                          ),
                        ),
                    ],
                  const Divider(height: 24),
                  Text(
                    '助记词',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.orange),
                  ),
                  if (!_hasPin || _mnemonicUnlocked) ...[
                    const SizedBox(height: 4),
                    Text(
                      _expandedMnemonic ?? '未知',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        if (_expandedMnemonic != null) {
                          _copyText(_expandedMnemonic!, '助记词');
                          _showError('请立即离线保存助记词');
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制助记词（谨慎）'),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _showPinVerifyDialog,
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('输入 PIN 查看助记词'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 根据链族选择显示合并二维码或单地址二维码。
  ///
  /// Cardano 链有 stake address 时显示合并二维码（payment + stake），
  /// 其他情况显示单地址二维码。
  void _showAddressQr(String address, ChainConfig config) {
    if (config.chainFamily == 'cardano' && _expandedStakeAddress != null) {
      _showCombinedQrDialog(address, _expandedStakeAddress!);
    } else {
      _showAddressQrDialog(address, config.name);
    }
  }

  /// 显示单地址二维码（EVM 等非 Cardano 链使用）
  ///
  /// QrImageView 内部使用 LayoutBuilder，与 AlertDialog 的 IntrinsicWidth
  /// 不兼容，需用 SizedBox 包裹提供明确尺寸以避免固有尺寸断言异常。
  /// 需设置 backgroundColor: Colors.white 确保暗色主题下 QR 码对比度。
  void _showAddressQrDialog(String address, String chainName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$chainName 地址二维码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _truncate(address),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '观察钱包扫描此二维码导入地址',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示合并地址二维码：包含 payment address + stake address
  ///
  /// 观察钱包扫码后可一次性导入两个地址。
  void _showCombinedQrDialog(String paymentAddress, String stakeAddress) {
    final combinedJson = jsonEncode({
      'paymentAddress': paymentAddress,
      'stakeAddress': stakeAddress,
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('地址二维码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(
                data: combinedJson,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '观察钱包扫描此二维码导入地址',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildImportForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导入助记词', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _mnemonicController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '输入 12 或 24 个单词，空格分隔',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passphraseController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'BIP-39 密码短语（可选）',
                border: OutlineInputBorder(),
                helperText: '设置后相同助记词会产生不同地址，请务必记住',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importMnemonic,
                    icon: const Icon(Icons.download),
                    label: const Text('导入'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _showingImportForm = false),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
