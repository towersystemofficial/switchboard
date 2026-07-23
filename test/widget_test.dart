import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fronter_log/main.dart';

void main() {
  testWidgets('SwitchBoard app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const SwitchBoardApp());

    expect(find.byType(SwitchBoardApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
