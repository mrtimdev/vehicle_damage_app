// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:vehicle_damage_analyzer/main.dart';

void main() {
  setUpAll(() {
    Hive.init('${Directory.systemTemp.path}/vehicle_damage_analyzer_test');
  });

  testWidgets('renders the vehicle damage analyzer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VehicleDamageApp()),
    );

    expect(find.text('Analyze'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
