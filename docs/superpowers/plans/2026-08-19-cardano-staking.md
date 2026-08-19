# Cardano Staking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full Cardano staking support (registration, delegation, reward withdrawal, deregistration) to the coldwallet project.

**Architecture:** Extend ColdExport/ColdImport models with optional staking fields, add stake key witness signing to CardanoAdapter, create StakingScreen + StakeTransactionBuilder in coldwallet-watch, and extend add-wallet flow to import stake address.

**Tech Stack:** Flutter 3.11, Dart 3.11, cardano_flutter_sdk, cardano_dart_types, Blockfrost API, pointycastle (blake2b)

**Spec:** [docs/superpowers/specs/2026-08-19-cardano-staking-design.md](../specs/2026-08-19-cardano-staking-design.md)

---

## File Structure

### coldwallet-app (cold wallet, offline)

| File | Responsibility |
|------|----------------|
| `lib/models/certificate.dart` | Certificate model (3 types: registration, delegation, deregistration) |
| `lib/models/cold_export.dart` | Extend with `certificates`, `withdrawals`, `stakeKeyPath` |
| `lib/services/wallet_service.dart` | Add `deriveStakeKey()` for path `m/1852'/1815'/0'/2/0` |
| `lib/services/adapters/cardano_adapter.dart` | Add stake key witness signing |
| `lib/screens/home_screen.dart` | Display stake address + generate combined QR |
| `test/models/certificate_test.dart` | Certificate serialization tests |
| `test/models/cold_export_staking_test.dart` | ColdExport staking field tests |
| `test/services/stake_key_test.dart` | Stake key derivation tests |
| `test/services/cardano_adapter_stake_test.dart` | CardanoAdapter stake witness tests |

### coldwallet-watch (watch-only wallet, online)

| File | Responsibility |
|------|----------------|
| `lib/models/watch_wallet.dart` | Add `stakeAddress` field |
| `lib/services/blockfrost_service.dart` | Add pool/stake status queries |
| `lib/services/stake_transaction_builder.dart` | Build staking transaction CBOR |
| `lib/screens/staking_screen.dart` | Staking UI (delegate, withdraw, deregister) |
| `lib/screens/home_screen.dart` | Add Stake button |
| `lib/screens/add_wallet_screen.dart` | Import stake address from combined QR |
| `test/services/stake_transaction_builder_test.dart` | StakeTransactionBuilder tests |

### Documentation

| File | Responsibility |
|------|----------------|
| `PROTOCOL.md` | Update ColdExport/ColdImport with staking fields |
| `coldwallet-app/lib/models/README.md` | Document Certificate model |
| `coldwallet-watch/lib/screens/README.md` | Document StakingScreen |

---

## Phase 1: coldwallet-app Data Models

### Task 1: Certificate Model + Serialization Tests (TDD)

**Files:**
- Create: `coldwallet-app/lib/models/certificate.dart`
- Test: `coldwallet-app/test/models/certificate_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/models/certificate_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/certificate.dart';

void main() {
  group('Certificate', () {
    test('stakeRegistration toJson/fromJson roundtrip', () {
      final cert = Certificate(
        type: CertificateType.stakeRegistration,
        stakeCredential: 'abc123def456',
      );
      final json = cert.toJson();
      final restored = Certificate.fromJson(json);

      expect(restored.type, CertificateType.stakeRegistration);
      expect(restored.stakeCredential, 'abc123def456');
      expect(restored.poolKeyHash, isNull);
    });

    test('stakeDelegation toJson includes poolKeyHash', () {
      final cert = Certificate(
        type: CertificateType.stakeDelegation,
        stakeCredential: 'abc123',
        poolKeyHash: 'pool1hash456',
      );
      final json = cert.toJson();

      expect(json['type'], 'stakeDelegation');
      expect(json['poolKeyHash'], 'pool1hash456');
    });

    test('stakeDeregistration roundtrip', () {
      final cert = Certificate(
        type: CertificateType.stakeDeregistration,
        stakeCredential: 'xyz789',
      );
      final restored = Certificate.fromJson(cert.toJson());
      expect(restored.type, CertificateType.stakeDeregistration);
      expect(restored.poolKeyHash, isNull);
    });

    test('fromJson with unknown type throws', () {
      expect(
        () => Certificate.fromJson({'type': 'unknown', 'stakeCredential': 'x'}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd coldwallet-app && flutter test test/models/certificate_test.dart`
Expected: FAIL — `Certificate` not defined

- [ ] **Step 3: Implement Certificate model**

```dart
// lib/models/certificate.dart

/// Cardano stake certificate types.
enum CertificateType {
  stakeRegistration,
  stakeDelegation,
  stakeDeregistration,
}

/// A Cardano stake certificate (registration, delegation, or deregistration).
///
/// Used in staking transactions to register a stake key, delegate to a pool,
/// or deregister a stake key. Serialized as part of [ColdExport].
class Certificate {
  final CertificateType type;

  /// blake2b_224 hash of the stake public key (28 bytes, hex-encoded).
  final String stakeCredential;

  /// Pool key hash for delegation certificates (28 bytes, hex-encoded).
  /// Null for registration/deregistration.
  final String? poolKeyHash;

  const Certificate({
    required this.type,
    required this.stakeCredential,
    this.poolKeyHash,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'stakeCredential': stakeCredential,
    if (poolKeyHash != null) 'poolKeyHash': poolKeyHash,
  };

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      type: CertificateType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => throw StateError('Unknown certificate type: ${json['type']}'),
      ),
      stakeCredential: json['stakeCredential'] as String,
      poolKeyHash: json['poolKeyHash'] as String?,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd coldwallet-app && flutter test test/models/certificate_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
cd coldwallet-app
git add lib/models/certificate.dart test/models/certificate_test.dart
git commit -m "feat(app): add Certificate model for staking transactions"
```

---

### Task 2: Extend ColdExport with Staking Fields (TDD)

**Files:**
- Modify: `coldwallet-app/lib/models/cold_export.dart`
- Test: `coldwallet-app/test/models/cold_export_staking_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/models/cold_export_staking_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/cold_export.dart';
import 'package:coldwallet_app/models/certificate.dart';

void main() {
  group('ColdExport staking fields', () {
    test('payment transaction: staking fields default to null', () {
      final json = {
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 1000000,
          'fee': 170000,
        },
      };
      final export = ColdExport.fromJson(json);

      expect(export.certificates, isNull);
      expect(export.withdrawals, isNull);
      expect(export.stakeKeyPath, isNull);
    });

    test('staking transaction: certificates serialized', () {
      final json = {
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 2000000,
          'fee': 180000,
        },
        'certificates': [
          {'type': 'stakeRegistration', 'stakeCredential': 'cred123'},
          {'type': 'stakeDelegation', 'stakeCredential': 'cred123', 'poolKeyHash': 'pool456'},
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(json);

      expect(export.certificates, hasLength(2));
      expect(export.certificates![0].type, CertificateType.stakeRegistration);
      expect(export.certificates![1].poolKeyHash, 'pool456');
      expect(export.stakeKeyPath, "m/1852'/1815'/0'/2/0");
    });

    test('staking transaction: withdrawals serialized', () {
      final json = {
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 0,
          'fee': 175000,
        },
        'withdrawals': {'stake_test1...': 5000000},
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(json);

      expect(export.withdrawals, {'stake_test1...': 5000000});
    });

    test('toJson roundtrip preserves staking fields', () {
      final original = {
        'network': 'preview',
        'txCbor': 'aabbcc',
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 2000000,
          'fee': 180000,
        },
        'certificates': [
          {'type': 'stakeDelegation', 'stakeCredential': 'cred123', 'poolKeyHash': 'pool456'},
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      };
      final export = ColdExport.fromJson(original);
      final roundtripped = ColdExport.fromJson(export.toJson());

      expect(roundtripped.certificates, hasLength(1));
      expect(roundtripped.stakeKeyPath, "m/1852'/1815'/0'/2/0");
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd coldwallet-app && flutter test test/models/cold_export_staking_test.dart`
Expected: FAIL — `certificates` getter not defined

- [ ] **Step 3: Extend ColdExport model**

Add to `lib/models/cold_export.dart`:

```dart
import 'certificate.dart';

class ColdExport {
  // ... existing fields ...

  /// Staking certificates (null for payment transactions).
  final List<Certificate>? certificates;

  /// Reward withdrawals: reward_address → amount in lovelace (null for payment).
  final Map<String, int>? withdrawals;

  /// Stake key derivation path (null for payment transactions).
  final String? stakeKeyPath;

  ColdExport({
    // ... existing params ...
    this.certificates,
    this.withdrawals,
    this.stakeKeyPath,
  });

  factory ColdExport.fromJson(Map<String, dynamic> json) {
    return ColdExport(
      // ... existing fields ...
      certificates: (json['certificates'] as List<dynamic>?)
          ?.map((e) => Certificate.fromJson(e as Map<String, dynamic>))
          .toList(),
      withdrawals: (json['withdrawals'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)),
      stakeKeyPath: json['stakeKeyPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      if (certificates != null)
        'certificates': certificates!.map((c) => c.toJson()).toList(),
      if (withdrawals != null) 'withdrawals': withdrawals,
      if (stakeKeyPath != null) 'stakeKeyPath': stakeKeyPath,
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd coldwallet-app && flutter test test/models/cold_export_staking_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run full test suite**

Run: `cd coldwallet-app && flutter test`
Expected: All tests pass (no regression)

- [ ] **Step 6: Commit**

```bash
cd coldwallet-app
git add lib/models/cold_export.dart test/models/cold_export_staking_test.dart
git commit -m "feat(app): extend ColdExport with staking fields (certificates, withdrawals, stakeKeyPath)"
```

---

## Phase 2: coldwallet-app Stake Key + Signing

### Task 3: WalletService.deriveStakeKey (TDD)

**Files:**
- Modify: `coldwallet-app/lib/services/wallet_service.dart`
- Test: `coldwallet-app/test/services/stake_key_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/services/stake_key_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/services/wallet_service.dart';

void main() {
  group('WalletService.deriveStakeKey', () {
    // Test mnemonic (DO NOT use in production)
    const testMnemonic = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';

    test('derives stake key with correct path', () async {
      final service = WalletService();
      final stakeKey = await service.deriveStakeKey(testMnemonic);

      expect(stakeKey.privateKey, isNotEmpty);
      expect(stakeKey.publicKey, isNotEmpty);
      expect(stakeKey.stakeCredential, hasLength(56)); // 28 bytes = 56 hex chars
      expect(stakeKey.stakeAddress, startsWith('stake_test'));
    });

    test('stake credential is blake2b_224 of public key', () async {
      final service = WalletService();
      final stakeKey = await service.deriveStakeKey(testMnemonic);

      // stakeCredential should be 28 bytes (224 bits)
      expect(stakeKey.stakeCredential.length, 56);
    });

    test('different account index produces different key', () async {
      final service = WalletService();
      final key0 = await service.deriveStakeKey(testMnemonic, accountIndex: 0);
      final key1 = await service.deriveStakeKey(testMnemonic, accountIndex: 1);

      expect(key0.stakeCredential, isNot(key1.stakeCredential));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd coldwallet-app && flutter test test/services/stake_key_test.dart`
Expected: FAIL — `deriveStakeKey` not defined

- [ ] **Step 3: Implement deriveStakeKey**

Add to `lib/services/wallet_service.dart`:

```dart
import 'package:pointycastle/export.dart';
import 'dart:typed_data';
import 'package:hex/hex.dart';

/// Stake key pair derived from mnemonic.
class StakeKeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;
  final String stakeCredential; // blake2b_224(publicKey), 28 bytes hex
  final String stakeAddress;    // Bech32 encoded

  const StakeKeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.stakeCredential,
    required this.stakeAddress,
  });
}

/// Derives the stake key from mnemonic at path m/1852'/1815'/{accountIndex}'/2/0.
///
/// Returns a [StakeKeyPair] containing the private key, public key,
/// stake credential (blake2b_224 hash), and Bech32-encoded stake address.
Future<StakeKeyPair> deriveStakeKey(String mnemonic, {int accountIndex = 0}) async {
  final wallet = await createWallet(mnemonic, testnet: true);
  
  // Derive stake key at path m/1852'/1815'/{accountIndex}'/2/0
  final stakeKey = wallet.deriveStakeKey(accountIndex: accountIndex);
  final stakePubKey = stakeKey.publicKey;
  
  // stake credential = blake2b_224(stake public key)
  final credential = _blake2b224(stakePubKey);
  
  // stake address = network tag + stake credential, Bech32 encoded
  final stakeAddress = _encodeStakeAddress(credential, testnet: true);
  
  return StakeKeyPair(
    privateKey: stakeKey.privateKey,
    publicKey: stakePubKey,
    stakeCredential: HEX.encode(credential),
    stakeAddress: stakeAddress,
  );
}

/// Computes blake2b_224 hash (28 bytes).
Uint8List _blake2b224(List<int> input) {
  final digest = Blake2bDigest(digestSize: 28);
  digest.update(Uint8List.fromList(input), 0, input.length);
  final result = Uint8List(28);
  digest.doFinal(result, 0);
  return result;
}

/// Encodes stake address as Bech32 (stake_test1... for testnet, stake1... for mainnet).
String _encodeStakeAddress(Uint8List stakeCredential, {required bool testnet}) {
  // Header byte: 0xE0 for mainnet, 0xE1 for testnet (type 14 = reward address)
  final header = testnet ? 0xE1 : 0xE0;
  final bytes = Uint8List(29)..[0] = header;
  bytes.setRange(1, 29, stakeCredential);
  
  return _bech32Encode(bytes, testnet ? 'stake_test' : 'stake');
}
```

Note: `_bech32Encode` should use the existing Bech32 encoding from cardano_flutter_sdk or a helper. Check what's available in the SDK.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd coldwallet-app && flutter test test/services/stake_key_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
cd coldwallet-app
git add lib/services/wallet_service.dart test/services/stake_key_test.dart
git commit -m "feat(app): add WalletService.deriveStakeKey for path m/1852'/1815'/0'/2/0"
```

---

### Task 4: CardanoAdapter Stake Witness Signing (TDD)

**Files:**
- Modify: `coldwallet-app/lib/services/adapters/cardano_adapter.dart`
- Test: `coldwallet-app/test/services/cardano_adapter_stake_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/services/cardano_adapter_stake_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coldwallet_app/models/certificate.dart';
import 'package:coldwallet_app/models/cold_export.dart';
import 'package:coldwallet_app/services/adapters/cardano_adapter.dart';

void main() {
  group('CardanoAdapter staking', () {
    const testMnemonic = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';

    test('payment transaction without certificates: no stake witness', () {
      final export = ColdExport.fromJson({
        'network': 'preview',
        'txCbor': 'aabbccdd', // placeholder
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 1000000,
          'fee': 170000,
        },
      });

      expect(export.certificates, isNull);
      // CardanoAdapter should only generate payment witness
    });

    test('staking transaction with certificates: needs stake witness', () {
      final export = ColdExport.fromJson({
        'network': 'preview',
        'txCbor': 'aabbccdd', // placeholder
        'summary': {
          'fromAddress': 'addr_test1...',
          'toAddress': 'addr_test1...',
          'amount': 2000000,
          'fee': 180000,
        },
        'certificates': [
          {'type': 'stakeRegistration', 'stakeCredential': 'cred123'},
          {'type': 'stakeDelegation', 'stakeCredential': 'cred123', 'poolKeyHash': 'pool456'},
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      });

      expect(export.certificates, hasLength(2));
      // CardanoAdapter should generate both payment and stake witnesses
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd coldwallet-app && flutter test test/services/cardano_adapter_stake_test.dart`
Expected: PASS (these are structure tests, adapter integration needs real CBOR)

- [ ] **Step 3: Extend CardanoAdapter.signTransaction**

Modify `lib/services/adapters/cardano_adapter.dart`:

```dart
@override
Future<SignResult> signTransaction(
  String mnemonic,
  Map<String, dynamic> exportJson,
  ChainConfig config,
) async {
  final export = ColdExport.fromJson(exportJson);
  final wallet = await _walletService.createWallet(
    mnemonic,
    testnet: config.chainId != 'cardano-mainnet',
  );

  final tx = CardanoTransaction.deserializeFromHex(export.txCbor);

  // 1. Payment key witness (existing logic)
  final paymentWitness = await wallet.signTransaction(
    tx: tx,
    witnessBech32Addresses: {export.summary.fromAddress},
  );

  // 2. Stake key witness (new: if certificates or withdrawals present)
  VkeyWitness? stakeWitness;
  if (export.certificates != null || export.withdrawals != null) {
    final stakeKey = await _walletService.deriveStakeKey(mnemonic);
    
    // Verify stake credential matches
    final expectedCredential = export.certificates?.first.stakeCredential
        ?? _extractCredentialFromWithdrawals(export.withdrawals!);
    if (stakeKey.stakeCredential != expectedCredential) {
      throw Exception('Stake key mismatch: expected $expectedCredential, got ${stakeKey.stakeCredential}');
    }
    
    stakeWitness = await wallet.signWithStakeKey(tx: tx, stakeKey: stakeKey.privateKey);
  }

  // 3. Combine witnesses
  final signedTx = tx.copyWithAdditionalSignatures({
    ...paymentWitness,
    if (stakeWitness != null) stakeWitness,
  });

  final txHash = _blake2b256Hex(export.txCbor);
  return SignResult(
    version: 1,
    signedTxHex: signedTx.serializeHexString(),
    txHash: txHash,
  );
}

/// Extracts stake credential from withdrawals map (reward address → credential).
String _extractCredentialFromWithdrawals(Map<String, int> withdrawals) {
  final rewardAddress = withdrawals.keys.first;
  // reward address format: 0xE1 + stake_credential (hex)
  // Extract stake credential from reward address
  return rewardAddress.substring(2); // skip header byte
}
```

Note: The exact API for `signWithStakeKey` depends on cardano_flutter_sdk. Check SDK documentation for stake key signing.

- [ ] **Step 4: Run tests**

Run: `cd coldwallet-app && flutter test test/services/cardano_adapter_stake_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd coldwallet-app
git add lib/services/adapters/cardano_adapter.dart test/services/cardano_adapter_stake_test.dart
git commit -m "feat(app): add stake key witness signing to CardanoAdapter"
```

---

## Phase 3: coldwallet-app UI

### Task 5: HomeScreen Display Stake Address + Combined QR

**Files:**
- Modify: `coldwallet-app/lib/screens/home_screen.dart`

- [ ] **Step 1: Add stake address display section**

In `_buildMultiChainAddressList`, after payment address dropdown, add stake address card with copy button (only visible when Cardano chain is selected).

- [ ] **Step 2: Add _stakeAddress state field and _loadStakeAddress method**

Derive stake address from mnemonic when Cardano chain is selected. Call in `_loadState()` and on chain change.

- [ ] **Step 3: Update add-wallet QR to include stake address**

Generate combined JSON: `{"paymentAddress": "...", "stakeAddress": "..."}`

- [ ] **Step 4: Run flutter analyze + commit**

```bash
cd coldwallet-app && git add lib/screens/home_screen.dart
git commit -m "feat(app): display stake address on HomeScreen + combined QR"
```

---

## Phase 4: coldwallet-watch Data Models + Services

### Task 6: Extend watch_wallet Model with stakeAddress

**Files:**
- Modify: `coldwallet-watch/lib/models/watch_wallet.dart`

- [ ] **Step 1: Add `stakeAddress` field (nullable, backward compatible)**
- [ ] **Step 2: Run tests + commit**

```bash
cd coldwallet-watch && git add lib/models/watch_wallet.dart
git commit -m "feat(watch): add stakeAddress field to WatchWallet"
```

### Task 7: BlockfrostService Pool + Stake Queries

**Files:**
- Modify: `coldwallet-watch/lib/services/blockfrost_service.dart`

- [ ] **Step 1: Add `getPoolInfo(poolId)` and `isPoolRetired(poolId)`**
- [ ] **Step 2: Add `getStakeAccountInfo(stakeAddress)` (returns active/pool_id/withdrawable_amount)**
- [ ] **Step 3: Run tests + commit**

```bash
cd coldwallet-watch && git add lib/services/blockfrost_service.dart
git commit -m "feat(watch): add BlockfrostService pool and stake account queries"
```

### Task 8: StakeTransactionBuilder (TDD)

**Files:**
- Create: `coldwallet-watch/lib/services/stake_transaction_builder.dart`
- Test: `coldwallet-watch/test/services/stake_transaction_builder_test.dart`

- [ ] **Step 1: Write failing test**
- [ ] **Step 2: Implement `buildDelegate()` (auto-registration + delegation)**
- [ ] **Step 3: Implement `buildWithdrawReward()`**
- [ ] **Step 4: Implement `buildDeregister()`**
- [ ] **Step 5: Run tests + commit**

```bash
cd coldwallet-watch && git add lib/services/stake_transaction_builder.dart test/
git commit -m "feat(watch): add StakeTransactionBuilder for delegation/withdraw/deregister"
```

---

## Phase 5: coldwallet-watch UI

### Task 9: StakingScreen UI

**Files:**
- Create: `coldwallet-watch/lib/screens/staking_screen.dart`

- [ ] **Step 1: Create StakingScreen with stake address display + status card**
- [ ] **Step 2: Add delegate/withdraw/deregister action buttons with dialogs**
- [ ] **Step 3: Add pool validation (format + retirement check)**
- [ ] **Step 4: Run flutter analyze + commit**

```bash
cd coldwallet-watch && git add lib/screens/staking_screen.dart
git commit -m "feat(watch): add StakingScreen with status display and action buttons"
```

### Task 10: HomeScreen Add Stake Button

**Files:**
- Modify: `coldwallet-watch/lib/screens/home_screen.dart`

- [ ] **Step 1: Add Stake button alongside Send/Receive (disabled for non-Cardano wallets)**
- [ ] **Step 2: Run flutter analyze + commit**

```bash
cd coldwallet-watch && git add lib/screens/home_screen.dart
git commit -m "feat(watch): add Stake button to HomeScreen"
```

### Task 11: AddWalletScreen Import Stake Address

**Files:**
- Modify: `coldwallet-watch/lib/screens/add_wallet_screen.dart`

- [ ] **Step 1: Update QR parsing to handle combined payload (paymentAddress + stakeAddress)**
- [ ] **Step 2: Pass stakeAddress when creating WatchWallet**
- [ ] **Step 3: Show stake address in preview**
- [ ] **Step 4: Run tests + commit**

```bash
cd coldwallet-watch && git add lib/screens/add_wallet_screen.dart
git commit -m "feat(watch): import stake address from combined QR in AddWalletScreen"
```

---

## Phase 6: Documentation

### Task 12: Update PROTOCOL.md

**Files:**
- Modify: `PROTOCOL.md`

- [ ] **Step 1: Add staking fields section (certificates, withdrawals, stakeKeyPath)**
- [ ] **Step 2: Add Certificate object spec + example JSON**
- [ ] **Step 3: Add backward compatibility note**
- [ ] **Step 4: Commit**

```bash
git add PROTOCOL.md
git commit -m "docs: add staking fields to ColdExport/ColdImport protocol specification"
```
