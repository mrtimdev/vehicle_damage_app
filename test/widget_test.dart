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

  testWidgets(
      'renders animated SplashScreen with SV - Vehicle Fault Detection then transitions to HomeScreen in Khmer and English',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VehicleDamageApp()),
    );

    // Initially shows the animated Splash Screen with app name & Khmer subtitle
    expect(find.text('SV - Vehicle Fault Detection'), findsOneWidget);
    expect(
      find.text('ប្រព័ន្ធ AI វិភាគកំហុស និងការខូចខាតរថយន្ត'),
      findsOneWidget,
    );

    // Advance through the splash animation to transition to HomeScreen
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();

    // Default language is Khmer (ខ្មែរ) with clean Khmer navigation tabs & SV title
    expect(find.text('SV - ពិនិត្យកំហុស និងការខូចខាតរថយន្ត'), findsOneWidget);
    expect(find.text('ទំព័រដើម'), findsOneWidget);
    expect(find.text('ប្រវត្តិ'), findsOneWidget);
    expect(find.text('របាយការណ៍'), findsOneWidget);
    expect(find.text('ការកំណត់'), findsOneWidget);

    // Tap language toggle to switch to English (EN)
    await tester.tap(find.text('ខ្មែរ'));
    await tester.pump();

    expect(find.text('SV - Vehicle Fault Detection'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
