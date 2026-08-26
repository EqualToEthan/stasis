/// 全局网络开关
///
/// 控制整个系统运行在测试网还是主网。
/// 改 `isMainnet` 一个字段即可切换全局网络，两个 app 同步生效。
///
/// 非 const：允许测试注入（在 setUp 中设 `AppConfig.isMainnet = true` 测主网逻辑，
/// tearDown 中设回 false）。该值不暴露给 UI、不读写存储，运行时可变的风险可忽略。
///
/// 详见 ADR-0003。
class AppConfig {
  /// 是否为主网模式。false = 测试网，true = 主网。
  static bool isMainnet = false;
}
