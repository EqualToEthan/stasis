import 'package:flutter/material.dart';

import 'package:coldwallet_protocol/coldwallet_protocol.dart';

import '../services/evm_rpc_config.dart';
import '../services/evm_rpc_service.dart';
import '../services/storage_service.dart';

/// EVM 代币管理页面
///
/// 用户可在此页面为指定 EVM 链添加或删除 ERC-20 代币合约地址。
/// 添加时会通过 RPC 实时校验合约是否可读（decimals + symbol）。
class ManageEvmTokensScreen extends StatefulWidget {
  /// 可选的 StorageService 注入，主要用于测试。
  final StorageService? storageService;

  /// 可选的 EvmRpcService 注入，主要用于测试。
  final EvmRpcService? rpcService;

  /// 可选的初始选中链 ID。
  ///
  /// 传入后页面会默认选中该链并隐藏链选择器，
  /// 用于从 [TokenManagementScreen] 按链进入的场景。
  final String? initialChainId;

  const ManageEvmTokensScreen({
    super.key,
    this.storageService,
    this.rpcService,
    this.initialChainId,
  });

  @override
  State<ManageEvmTokensScreen> createState() => _ManageEvmTokensScreenState();
}

class _ManageEvmTokensScreenState extends State<ManageEvmTokensScreen> {
  late StorageService _storage;
  late EvmRpcService _rpc;
  bool _initialized = false;

  final List<ChainConfig> _chainOptions = ChainRegistry.configsForFamily('evm');
  String? _selectedChainId;
  List<String> _contracts = [];

  final _addressController = TextEditingController();
  bool _validating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storage = widget.storageService ?? await StorageService.create();
    final rpc = widget.rpcService ?? EvmRpcService();
    final initialChain = _resolveInitialChain();
    final contracts = initialChain != null
        ? await storage.getEvmTokenContracts(initialChain)
        : <String>[];
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _rpc = rpc;
      _selectedChainId = initialChain;
      _contracts = contracts;
      _initialized = true;
    });
  }

  /// 无指定链时的默认选中链：与 HomeScreen 默认链一致（BSC，Q13 决策）。
  /// 注册顺序中 Ethereum 排在 BSC 之前，直接取第一条会偏离默认链约定。
  String? _resolveInitialChain() {
    final requested = widget.initialChainId;
    if (requested != null && _chainOptions.any((c) => c.chainId == requested)) {
      return requested;
    }
    final defaultChainId = AppConfig.isMainnet ? 'evm-56' : 'evm-97';
    if (_chainOptions.any((c) => c.chainId == defaultChainId)) {
      return defaultChainId;
    }
    return _chainOptions.firstOrNull?.chainId;
  }

  Future<void> _loadContracts() async {
    final chainId = _selectedChainId;
    if (chainId == null) return;
    final contracts = await _storage.getEvmTokenContracts(chainId);
    if (!mounted) return;
    setState(() => _contracts = contracts);
  }

  Future<String> _resolveRpcUrl(String chainId) =>
      EvmRpcConfig.resolveRpcUrl(_storage, chainId);

  Future<void> _addToken() async {
    final chainId = _selectedChainId;
    if (chainId == null) return;

    final address = _addressController.text.trim().toLowerCase();
    if (address.isEmpty) {
      setState(() => _validationError = '请输入合约地址');
      return;
    }
    if (!address.startsWith('0x') || address.length != 42) {
      setState(() => _validationError = '地址格式应为 0x 前缀的 40 位 hex');
      return;
    }
    if (_contracts.contains(address)) {
      setState(() => _validationError = '该合约已存在');
      return;
    }

    setState(() {
      _validating = true;
      _validationError = null;
    });

    try {
      final rpcUrl = await _resolveRpcUrl(chainId);
      final readable = await _rpc.isErc20Readable(rpcUrl, address);
      if (!readable) {
        if (!mounted) return;
        setState(() {
          _validating = false;
          _validationError = '无法读取该合约的 ERC-20 元数据，请检查地址和 RPC';
        });
        return;
      }

      final updated = [..._contracts, address];
      await _storage.setEvmTokenContracts(chainId, updated);
      _addressController.clear();
      await _loadContracts();
      if (!mounted) return;
      setState(() => _validating = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _validationError = '校验失败: $e';
      });
    }
  }

  Future<void> _removeToken(String address) async {
    final chainId = _selectedChainId;
    if (chainId == null) return;
    final updated = _contracts.where((a) => a != address).toList();
    await _storage.setEvmTokenContracts(chainId, updated);
    await _loadContracts();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('管理 EVM 代币')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.initialChainId == null) ...[
              _buildChainSelector(),
              const SizedBox(height: 24),
            ],
            _buildAddForm(),
            const SizedBox(height: 16),
            Expanded(child: _buildTokenList()),
          ],
        ),
      ),
    );
  }

  Widget _buildChainSelector() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '选择链',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedChainId,
          isDense: true,
          isExpanded: true,
          items: _chainOptions.map((chain) {
            return DropdownMenuItem(
              value: chain.chainId,
              child: Text(chain.name),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedChainId = value);
            _loadContracts();
          },
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'ERC-20 合约地址',
            hintText: '0x...',
            border: OutlineInputBorder(),
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _validationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _validating ? null : _addToken,
            child: _validating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('添加并校验'),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenList() {
    if (_contracts.isEmpty) {
      return const Center(child: Text('该链尚未添加任何 ERC-20 代币'));
    }
    return ListView.separated(
      itemCount: _contracts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contract = _contracts[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            contract,
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeToken(contract),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}
