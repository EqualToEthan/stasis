import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet_info.dart';
import '../services/wallet_service.dart';
import 'dice_entropy_screen.dart';

/// 钱包管理页面
///
/// 展示所有钱包列表，支持：查看详情/备份助记词、删除钱包、
/// 新增钱包（生成/掷骰子/导入）。首次进入时引导创建第一个钱包。
class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final WalletService _walletService = WalletService();
  final TextEditingController _mnemonicController = TextEditingController();

  List<WalletInfo> _wallets = [];
  String _network = 'testnet';
  bool _isLoading = true;
  bool _hasPin = false;

  // 当前正在查看详情的钱包
  String? _expandedWalletId;
  String? _expandedAddress;
  String? _expandedMnemonic;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final wallets = await _walletService.getWallets();
    final network = await _walletService.getNetwork();
    final hasPin = await _walletService.hasPin();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _network = network;
      _hasPin = hasPin;
      _isLoading = false;
      _expandedWalletId = null;
      _expandedAddress = null;
      _expandedMnemonic = null;
    });
  }

  Future<void> _expandWallet(WalletInfo wallet) async {
    if (_expandedWalletId == wallet.id) {
      setState(() {
        _expandedWalletId = null;
        _expandedAddress = null;
        _expandedMnemonic = null;
      });
      return;
    }
    // 临时切换以获取该钱包的信息
    final prevWallet = await _walletService.getCurrentWallet();
    await _walletService.switchWallet(wallet.id);
    final m = await _walletService.loadCurrentMnemonic();
    final isTestnet = _network != 'mainnet';
    final address = m != null
        ? await _walletService.deriveAddress(m, testnet: isTestnet)
        : null;
    // 恢复之前选中的钱包
    if (prevWallet != null) {
      await _walletService.switchWallet(prevWallet.id);
    }
    if (!mounted) return;
    setState(() {
      _expandedWalletId = wallet.id;
      _expandedAddress = address;
      _expandedMnemonic = m;
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
    setState(() => _showingImportForm = true);
  }

  Future<void> _importMnemonic() async {
    final mnemonic = _mnemonicController.text.trim();
    if (!_walletService.validateMnemonic(mnemonic)) {
      _showError('助记词无效，请检查拼写和词数');
      return;
    }
    setState(() => _showingImportForm = false);
    _showNameAndConfirmDialog(mnemonic, isNew: false);
  }

  /// 显示命名 + 助记词确认 + PIN 设置对话框
  void _showNameAndConfirmDialog(String mnemonic, {required bool isNew}) {
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
              _showMnemonicConfirm(mnemonic, name: name, isNew: isNew);
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
              _showPinDialog(mnemonic, name: name);
            },
            child: const Text('已备份，继续'),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(String mnemonic, {required String name}) {
    // 如果已有 PIN，不需要再次设置
    if (_hasPin) {
      _saveWallet(mnemonic, name: name);
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
              await _saveWallet(mnemonic, name: name);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWallet(String mnemonic, {required String name}) async {
    try {
      await _walletService.addWallet(name: name, mnemonic: mnemonic);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 已复制')));
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
          ],
        ],
      ),
    );
  }

  Widget _buildWalletCard(WalletInfo wallet) {
    final isExpanded = _expandedWalletId == wallet.id;
    return Card(
      child: Column(
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
          if (isExpanded && _expandedAddress != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('地址', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    _expandedAddress!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _copyText(_expandedAddress!, '地址'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制地址'),
                  ),
                  const Divider(height: 24),
                  Text(
                    '助记词',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.orange),
                  ),
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
                ],
              ),
            ),
          ],
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
