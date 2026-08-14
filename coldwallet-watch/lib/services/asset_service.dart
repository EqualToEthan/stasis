import '../models/asset_balance.dart';
import 'blockfrost_service.dart';
import 'storage_service.dart';

/// 资产查询服务
///
/// 通过 Blockfrost 获取地址余额，并结合用户启用配置返回资产列表。
class AssetService {
  final BlockfrostService _blockfrost;
  final StorageService _storage;

  AssetService(this._blockfrost, this._storage);

  /// 加载指定地址的资产余额
  ///
  /// [address] Cardano 地址
  /// [walletId] 钱包 ID，用于查询用户启用的资产列表
  Future<List<AssetBalance>> loadBalances(
    String address,
    String walletId,
  ) async {
    final data = await _blockfrost.getAddressBalance(address);
    final amountList = (data['amount'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final enabledUnits = await _storage.getEnabledAssets(walletId);

    return amountList.map((item) {
      final unit = item['unit'] as String;
      return AssetBalance(
        unit: unit,
        quantity: item['quantity'] as String,
        displayName: _displayName(unit),
        isEnabled: enabledUnits.contains(unit),
      );
    }).toList();
  }

  /// 生成资产的显示名称
  ///
  /// ADA 显示为 'ADA'，原生代币截断显示 hex 标识。
  String _displayName(String unit) {
    if (unit == 'lovelace') return 'ADA';
    // For tokens/NFTs, truncate or lookup; MVP uses hex unit as fallback.
    return unit.length > 20
        ? '${unit.substring(0, 8)}...${unit.substring(unit.length - 8)}'
        : unit;
  }
}
