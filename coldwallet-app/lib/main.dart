/// Cardano 冷钱包 App 入口
///
/// 完全离线的冷钱包应用，用于助记词管理、离线签名和交易导出。
/// 通过二维码或文件与联网端（观察钱包）交互。
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/wallet_setup_screen.dart';
import 'screens/scan_tx_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ColdWalletApp());
}

/// 冷钱包 App 根组件
///
/// 配置 Material3 主题（支持亮色/暗色）、路由表。
/// 路由包括：首页、钱包管理、扫码签名。
class ColdWalletApp extends StatelessWidget {
  const ColdWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardano Cold Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/wallet-setup': (context) => const WalletSetupScreen(),
        '/scan-tx': (context) => const ScanTxScreen(),
      },
    );
  }
}
