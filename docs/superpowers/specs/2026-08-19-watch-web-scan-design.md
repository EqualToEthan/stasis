# watch 端跨平台二维码扫码（web 支持 + 图片上传）

- 日期：2026-08-19
- 关联子项目：coldwallet-watch
- 关联计划：docs/superpowers/plans/（待生成）

## 背景与问题

coldwallet-watch 的扫码组件 [qr_scanner.dart](../../../coldwallet-watch/lib/widgets/qr_scanner.dart) 依赖 `mobile_scanner: ^3.0.0`（解析到 3.5.7）。`mobile_scanner` v3 不支持 web 平台——它依赖原生相机 API，浏览器中没有对应能力，导致 web 端点击"扫描二维码"后相机不启动。

用户需要在 web 浏览器中快速验证 watch 端流程，并希望扫码能力跨平台（含 web），同时支持上传二维码图片识别。

对比：coldwallet-app 已升级至 `mobile_scanner: ^7.4.0`（支持 web），其 [scan_tx_screen.dart](../../../coldwallet-app/lib/screens/scan_tx_screen.dart) 已验证 v7 用法（`MobileScanner(onDetect:...)` + `BarcodeCapture.barcodes`），与 watch 端现有写法基本兼容。

## 目标

1. 升级 coldwallet-watch 的 `mobile_scanner` 到 `^7.4.0`（与 app 端一致），使摄像头扫码在 web + 原生全平台工作。
2. 在扫码组件 `QRScanner` 内新增"从相册选图"能力，支持上传二维码图片识别：原生用 `MobileScannerController.analyzeImage`，web 用浏览器内置 `BarcodeDetector` API。
3. 复用现有 `onScan` 回调，调用方（add_wallet_screen / import_signed_screen）零改动即获得图片扫码能力。

## 非目标

- 不改造 `import_signed_screen._pickFile`（其使用 `dart:io` 的 `File`，web 不兼容，另案处理，记为已知限制）。
- 不引入 jsQR 等额外 JS 依赖（web 图片识别用浏览器内置 `BarcodeDetector`）。
- 不改 coldwallet-app（已为 v7）。
- 不做网络/钱包业务逻辑改动。

## 技术选型

| 关注点 | 选型 | 理由 |
|---|---|---|
| 扫码库 | `mobile_scanner: ^7.4.0` | 与 app 端一致；v5.0+ web 自动加载脚本；web 后端默认 Auto（BarcodeDetector 优先，回退 zxing-wasm） |
| 原生图片识别 | `MobileScannerController.analyzeImage(path)` | v7 支持 Android/iOS/macOS，无需额外依赖 |
| web 图片识别 | W3C `BarcodeDetector` API（`dart:js_interop`） | 浏览器内置无新依赖；Chrome 83+/Edge 83+/Safari 17+；Firefox 不支持→降级提示 |
| 选图 | `file_picker`（已依赖） | 复用现有依赖 |

## 架构设计

### 1. 组件改造：QRScanner（lib/widgets/qr_scanner.dart）

由 `StatelessWidget` 改为 `StatefulWidget`，持有 `MobileScannerController`（管理生命周期 + 提供图片识别能力）。

参数：
- `onScan(String)` —— 必填，扫码/识图成功回调（签名不变，向后兼容）。
- `showGalleryButton` —— 可选，默认 `true`，控制是否显示"从相册选图"按钮。

布局（`Column`，同时适配全屏式与嵌入式调用方）：
```
Column [
  Expanded( MobileScanner(controller, onDetect) ),   // 摄像头预览为主体
  if (showGalleryButton) OutlinedButton.icon('从相册选图'),
]
```

行为：
- 摄像头扫码：`onDetect` 取 `capture.barcodes.first.rawValue` → `onScan(value)`（与现有逻辑一致）。
- 从相册选图：`FilePicker.pickFile(type: FileType.image)` → 取文件路径/bytes → 调 `QrImageScanner.instance.scanImage(...)` → 成功 `onScan(result)`；失败 `SnackBar` 提示。
- `dispose`：释放 `MobileScannerController`。

### 2. 图片识别模块（条件导入，按平台切换实现）

- `lib/services/qr_image_scanner.dart`：抽象接口 + 条件导入工厂
  ```dart
  abstract interface class QrImageScanner {
    Future<String?> scanImage(Uint8List bytes, {String? path});
    static final QrImageScanner instance = _instance;
  }
  // 条件导入
  import 'qr_image_scanner_stub.dart'
    if (dart.library.io) 'qr_image_scanner_native.dart'
    if (dart.library.html) 'qr_image_scanner_web.dart';
  ```
- `lib/services/qr_image_scanner_stub.dart`：默认 stub，`scanImage` 抛 `UnsupportedError`。
- `lib/services/qr_image_scanner_native.dart`：原生实现
  - 自建临时 `MobileScannerController` 实例调用 `analyzeImage(path)`（不复用组件摄像头 controller，避免状态冲突）。
  - 从返回的 `BarcodeCapture.barcodes.firstOrNull?.rawValue` 取结果。
- `lib/services/qr_image_scanner_web.dart`：web 实现
  - `dart:js_interop` 绑定 `BarcodeDetector`：`const detector = BarcodeDetector();`
  - 将图片 bytes 转为 `ImageBitmap`（`createImageBitmap`），`detector.detect(bitmap)` → 取首个 `rawValue`。
  - 浏览器不支持 `BarcodeDetector` 时抛明确异常（调用方提示"当前浏览器不支持图片识别"）。

### 3. 调用方（零改动）

- [add_wallet_screen.dart](../../../coldwallet-watch/lib/screens/add_wallet_screen.dart)：`_showingScanner` 全屏分支 `QRScanner(onScan: _handleQrResult)`，自动获得图片按钮。
- [import_signed_screen.dart](../../../coldwallet-watch/lib/screens/import_signed_screen.dart)：`Expanded(child: QRScanner(onScan: _parseAndSubmit))`，自动获得图片按钮。

## 文件改动清单

| 文件 | 改动类型 | 说明 |
|---|---|---|
| coldwallet-watch/pubspec.yaml | 修改 | `mobile_scanner: ^3.0.0` → `^7.4.0` |
| coldwallet-watch/lib/widgets/qr_scanner.dart | 修改 | StatefulWidget + controller + 从相册按钮 |
| coldwallet-watch/lib/services/qr_image_scanner.dart | 新增 | 接口 + 条件导入工厂 |
| coldwallet-watch/lib/services/qr_image_scanner_stub.dart | 新增 | 默认 stub |
| coldwallet-watch/lib/services/qr_image_scanner_native.dart | 新增 | analyzeImage 实现 |
| coldwallet-watch/lib/services/qr_image_scanner_web.dart | 新增 | BarcodeDetector 实现 |
| coldwallet-watch/lib/widgets/README.md | 修改 | 同步 qr_scanner 新能力说明 |
| coldwallet-watch/lib/services/README.md | 修改 | 新增 qr_image_scanner 模块说明 |

## 平台限制

- **web 摄像头扫码**：需 secure context（HTTPS 或 localhost）+ 摄像头权限。预览浏览器若在 iframe 内可能被 permissions policy 限制 `camera`，需"在新标签页打开"使用。
- **web 图片识别**：`BarcodeDetector` 不需摄像头权限，iframe 内可用；Firefox 不支持（提示"当前浏览器不支持图片识别，请用 Chrome/Edge"）。
- **原生**：需相机权限（AndroidManifest/Info.plist）。app 端已配置，watch 端构建时确认权限声明齐全。

## 测试计划

- **单元测试**：`qr_image_scanner` 接口与结果解析逻辑（mock `BarcodeCapture`）。
- **widget 测试**：`QRScanner` 渲染"从相册"按钮、`onScan` 回调触发。
- **手动验证（web）**：`flutter run -d web-server --web-port=8090`，扫码页显示；授予摄像头权限后摄像头扫码工作；图片上传识别工作（Chrome）。
- **手动验证（native）**：`flutter test` 通过；`flutter build apk --debug` 构建成功。

## 风险与缓解

- **mobile_scanner v3→v7 breaking changes**：核对 app 端 v7 用法（`onDetect` + `BarcodeCapture.barcodes`）与 watch 现有写法兼容，摄像头扫码核心逻辑无需改；仅图片识别用 v7 新增的 `analyzeImage`。
- **web iframe 摄像头受限**：提示用户新标签页打开；图片识别作为 fallback 不受此限制。
- **BarcodeDetector 浏览器兼容**：不支持时明确提示，不崩溃。

## 已知限制（不在本次范围）

- `import_signed_screen._pickFile` 使用 `dart:io` 的 `File`，web 上不兼容（file_picker 在 web 返回 bytes 而非本地路径）。本次不改，记录待后续统一处理 web 文件导入。
