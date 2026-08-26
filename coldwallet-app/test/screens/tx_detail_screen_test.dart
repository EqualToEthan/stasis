import 'dart:convert';

import 'package:coldwallet_app/screens/tx_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TxDetailScreen Cardano', () {
    testWidgets('shows withdrawal reward amount', (tester) async {
      final rawJson = jsonEncode({
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor':
            '84a60081825820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000181a200583900aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00021a00030d40031a00030d400a0f5f6',
        'summary': {
          'fromAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'toAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'assets': [
            {'unit': 'lovelace', 'quantity': '0'},
          ],
          'fee': '200000',
        },
        'withdrawals': {
          'stake_test1uz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwqvqljap':
              63804,
        },
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      });

      await tester.pumpWidget(
        MaterialApp(home: TxDetailScreen(rawJson: rawJson)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('提取奖励'), findsOneWidget);
      expect(find.textContaining('0.063804'), findsOneWidget);
    });

    testWidgets('shows DRep abstain delegation from certificates', (
      tester,
    ) async {
      final rawJson = jsonEncode({
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor':
            '84a60081825820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000181a200583900aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00021a00030d40031a00030d400a0f5f6',
        'summary': {
          'fromAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'toAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'assets': [
            {'unit': 'lovelace', 'quantity': '0'},
          ],
          'fee': '200000',
        },
        'certificates': [
          {
            'type': 'stakeDelegation',
            'stakeCredential': 'a1b2c3d4e5f6',
            'poolKeyHash': 'pool1abc...',
          },
          {
            'type': 'voteDelegation',
            'stakeCredential': 'a1b2c3d4e5f6',
            'dRepType': 'abstain',
          },
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      });

      await tester.pumpWidget(
        MaterialApp(home: TxDetailScreen(rawJson: rawJson)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DRep 委托'), findsOneWidget);
      expect(find.text('弃权（abstain）'), findsOneWidget);
    });

    testWidgets('shows DRep key hash delegation from certificates', (
      tester,
    ) async {
      final rawJson = jsonEncode({
        'version': 1,
        'type': 'unsigned-tx',
        'network': 'preview',
        'txCbor':
            '84a60081825820aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000181a200583900aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00021a00030d40031a00030d400a0f5f6',
        'summary': {
          'fromAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'toAddress':
              'addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjqnnj83ws8lhrn648jjxtwq9rlvq',
          'assets': [
            {'unit': 'lovelace', 'quantity': '0'},
          ],
          'fee': '200000',
        },
        'certificates': [
          {
            'type': 'voteDelegation',
            'stakeCredential': 'a1b2c3d4e5f6',
            'dRepType': 'keyHash',
            'dRepHash': 'd5b18fd6a48c0de1a2b3c4d5e6f70819',
          },
        ],
        'stakeKeyPath': "m/1852'/1815'/0'/2/0",
      });

      await tester.pumpWidget(
        MaterialApp(home: TxDetailScreen(rawJson: rawJson)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DRep 委托'), findsOneWidget);
      // hash 截断展示：前 8 + ... + 后 8
      expect(find.textContaining('d5b18fd6'), findsOneWidget);
      expect(find.textContaining('e6f70819'), findsOneWidget);
    });
  });
}
