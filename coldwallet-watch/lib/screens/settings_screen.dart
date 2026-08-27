import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import 'about_screen.dart';
import 'network_api_settings_screen.dart';
import 'token_management_screen.dart';

/// 设置页面
///
/// 作为设置分类的入口，列出各大设置分类。
/// 点击分类进入对应的子设置页。
class SettingsScreen extends StatelessWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  const SettingsScreen({super.key, this.storageService});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _CategoryCard(
            icon: Icons.network_check,
            title: '网络与 API',
            subtitle: '网络环境、Blockfrost Key、EVM RPC 节点',
            onTap: () => _navigate(
              context,
              NetworkApiSettingsScreen(storageService: storageService),
            ),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            icon: Icons.token,
            title: '代币管理',
            subtitle: '管理各链上的 ERC-20 代币',
            onTap: () => _navigate(
              context,
              TokenManagementScreen(storageService: storageService),
            ),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '应用版本与说明',
            onTap: () => _navigate(context, const AboutScreen()),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
