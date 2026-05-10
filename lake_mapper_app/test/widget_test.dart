import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lake_mapper_app/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LakeMapperApp());
    await tester.pumpAndSettle();
    
    // Verify app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}