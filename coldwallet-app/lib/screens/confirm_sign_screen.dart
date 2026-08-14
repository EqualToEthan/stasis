import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cold_export.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'export_signed_screen.dart';

/// PIN 验证并签名交易页面
///
/// 用户在此输入 PIN，验证通过后调用 [TransactionService] 对 [ColdExport] 签名，
/// 签名成功后跳转到 [ExportSignedScreen] 展示已签名交易。
class ConfirmSignScreen extends StatefulWidget {
  final ColdExport coldExport;

  const ConfirmSignScreen({super.key, required this.coldExport});

  @override
  State<ConfirmSignScreen> createState() => _ConfirmSignScreenState();
}

class _ConfirmSignScreenState extends State<ConfirmSignScreen> {
  final WalletService _walletService = WalletService();
  final TextEditingController _pinController = TextEditingController();

  bool _isSigning = false;
  bool _obscurePin = true;

  Future<void> _verifyAndSign() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      _showError('请输入 6 位数字 PIN');
      return;
    }

    final pinValid = await _walletService.verifyPin(pin);
    if (!pinValid) {
      HapticFeedback.mediumImpact();
      _showError('PIN 错误');
      return;
    }

    setState(() => _isSigning = true);

    try {
      final transactionService = TransactionService(_walletService);
      final coldImport = await transactionService.signTransaction(widget.coldExport);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ExportSignedScreen(coldImport: coldImport),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigning = false);
      _showError('签名失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认签名'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 24),
            Text(
              '请输入 PIN 以授权签名',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '此操作将使用本设备保存的私钥对交易进行离线签名',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: _obscurePin,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: '6 位 PIN',
                counterText: '',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isSigning ? null : _verifyAndSign,
              icon: _isSigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit),
              label: Text(_isSigning ? '签名中...' : '确认并签名'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
