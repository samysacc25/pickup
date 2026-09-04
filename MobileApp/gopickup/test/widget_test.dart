import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gopickup/main.dart';

void main() {
  testWidgets('La app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const GoPickupApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
