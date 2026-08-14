import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/wallet_service.dart';

/// 骰子熵页面
///
/// 用户掷物理骰子 256 次，每次输入朝上的数字（1-6），
/// 奇数记为 1、偶数记为 0，收集 256 bits 真随机熵，
/// 生成标准 BIP-39 24 词助记词。
///
/// 完成时通过 Navigator.pop 返回生成的助记词字符串。
class DiceEntropyScreen extends StatefulWidget {
  const DiceEntropyScreen({super.key});

  @override
  State<DiceEntropyScreen> createState() => _DiceEntropyScreenState();
}

class _DiceEntropyScreenState extends State<DiceEntropyScreen> {
  static const int _totalRolls = 256;

  final WalletService _walletService = WalletService();
  final List<bool> _bits = [];

  double get _progress => _bits.length / _totalRolls;
  bool get _isComplete => _bits.length >= _totalRolls;

  void _onRoll(int face) {
    HapticFeedback.lightImpact();
    setState(() {
      _bits.add(face.isOdd); // 奇数=1, 偶数=0
    });

    if (_isComplete) {
      _generateMnemonic();
    }
  }

  void _undoLastRoll() {
    if (_bits.isEmpty) return;
    setState(() => _bits.removeLast());
  }

  void _resetAll() {
    setState(() => _bits.clear());
  }

  void _generateMnemonic() {
    try {
      final mnemonic = _walletService.mnemonicFromDiceBits(_bits);
      if (mounted) Navigator.pop(context, mnemonic);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('掷骰子生成助记词'),
        actions: [
          if (_bits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重置',
              onPressed: _showResetConfirm,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 进度区域 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 计数
                  Text(
                    '${_bits.length} / $_totalRolls',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isComplete ? '已完成！' : '请掷骰子并输入朝上的数字',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // ─── 说明区域 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                color: Colors.blueGrey.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueGrey,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '奇数(1,3,5)记为 1，偶数(2,4,6)记为 0\n'
                          '共需 256 次投掷以生成 24 词助记词',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ─── 骰子按钮区域 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 第一行: 1, 2, 3
                  Row(
                    children: [
                      1,
                      2,
                      3,
                    ].map((n) => _buildDiceButton(n)).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 第二行: 4, 5, 6
                  Row(
                    children: [
                      4,
                      5,
                      6,
                    ].map((n) => _buildDiceButton(n)).toList(),
                  ),
                  const SizedBox(height: 16),
                  // 撤销按钮
                  OutlinedButton.icon(
                    onPressed: _bits.isNotEmpty ? _undoLastRoll : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('撤销上一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceButton(int face) {
    final isOdd = face.isOdd;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          height: 72,
          child: ElevatedButton(
            onPressed: _isComplete ? null : () => _onRoll(face),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOdd
                  ? Colors.blueGrey.shade100
                  : Colors.orange.shade50,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$face',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isOdd ? '→ 1' : '→ 0',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置进度'),
        content: const Text('确定要清除已输入的投掷记录，重新开始吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAll();
            },
            child: const Text('重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
