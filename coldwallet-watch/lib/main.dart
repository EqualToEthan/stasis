// 观察钱包 App 入口
//
// 启动 coldwallet-watch 应用，这是 Cardano 冷钱包的联网端（只读），
// 用于查看余额、构建交易和提交已签名交易。
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const ColdWalletWatchApp());
}
