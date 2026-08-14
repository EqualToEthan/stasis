import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coldwallet_watch/app.dart';

void main() {
  testWidgets('App shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ColdWalletWatchApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
