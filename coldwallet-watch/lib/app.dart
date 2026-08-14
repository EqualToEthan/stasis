import 'package:flutter/material.dart';

import 'screens/add_wallet_screen.dart';
import 'screens/export_tx_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_signed_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';

/// 观察钱包 App 根组件
///
/// 配置 MaterialApp 路由表和 Material3 主题。
/// 路由包括：首页、添加钱包、发送、收款、导出交易、导入签名、设置。
class ColdWalletWatchApp extends StatelessWidget {
  const ColdWalletWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stasis Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/add-wallet': (context) => const AddWalletScreen(),
        '/send': (context) => const SendScreen(),
        '/receive': (context) => const ReceiveScreen(),
        '/export-tx': (context) => const ExportTxScreen(),
        '/import-signed': (context) => const ImportSignedScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
