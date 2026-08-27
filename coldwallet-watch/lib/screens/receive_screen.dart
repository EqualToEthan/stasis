import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';
import '../models/watch_wallet.dart';

/// 收款页面
///
/// 展示钱包地址的二维码和完整地址文本，
/// 支持复制到剪贴板，并提示用户仅接收对应网络的资产。
class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = ModalRoute.of(context)?.settings.arguments;
    if (wallet is! WatchWallet) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('无钱包数据'))),
      );
    }

    final chainName = _resolveChainName(wallet);

    return Scaffold(
      appBar: AppBar(title: const Text('收款')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                '仅接收 $chainName 网络的资产',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: wallet.address,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      wallet.address,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: wallet.address),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('地址已复制')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制地址'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据钱包信息解析出用于提示的链显示名称。
  ///
  /// EVM 钱包使用保存的 chainId 从 [ChainRegistry] 查找具体链名；
  /// Cardano 钱包若未保存 chainId，则按 [AppConfig.isMainnet] 回退到
  /// cardano-mainnet / cardano-preview 配置。
  String _resolveChainName(WatchWallet wallet) {
    final chainId = wallet.chainId;
    if (chainId != null) {
      return ChainRegistry.getConfig(chainId)?.name ?? chainId;
    }
    final fallbackId = AppConfig.isMainnet
        ? 'cardano-mainnet'
        : 'cardano-preview';
    return ChainRegistry.getConfig(fallbackId)?.name ??
        (AppConfig.isMainnet ? 'Mainnet' : 'Preview');
  }
}
