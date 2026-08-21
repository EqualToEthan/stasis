# widgets 模块

观察钱包的可复用 UI 组件。封装了二维码的显示和扫描功能，被 screens 层的多个页面复用。

## 文件清单

| 文件 | 主要类 | 功能说明 |
|------|--------|----------|
| qr_display.dart | QRDisplay | 二维码显示组件，封装 qr_flutter 的 QrImageView |
| qr_scanner.dart | QRScanner | 二维码扫描组件，封装 mobile_scanner (^7.4.0)，支持 Web + Android 摄像头扫码，扫描成功回调原始字符串 |

## 依赖关系

- **内部依赖**：无（纯 UI 组件，不依赖 models 或 services）
- **外部依赖**：
  - `qr_flutter` — 二维码生成和渲染
  - `mobile_scanner` — 摄像头二维码扫描

## 常见修改指引

| 我想... | 修改文件 |
|---------|---------|
| 修改二维码的尺寸或样式 | qr_display.dart — 修改 size、backgroundColor 等参数 |
| 添加扫描成功后的提示音/震动 | qr_scanner.dart — 在 onDetect 中添加 HapticFeedback |
| 支持扫描其他类型的码 | qr_scanner.dart — 修改 onDetect 回调中的解析逻辑 |
