// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medinfo/main.dart';  // 프로젝트명에 맞게 수정

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 수정: MyApp -> MedicineBarcodeScannerApp
    await tester.pumpWidget(const MedicineBarcodeScannerApp());

    // 나머지는 주석 처리하거나 삭제
    // expect(find.text('0'), findsOneWidget);
    // expect(find.text('1'), findsNothing);
  });
}