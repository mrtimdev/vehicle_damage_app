import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vehicle_damage_analyzer/models/damage_report.dart';
import 'package:vehicle_damage_analyzer/screens/capture_screen.dart';
import 'package:vehicle_damage_analyzer/screens/report_screen.dart';
import 'package:vehicle_damage_analyzer/utils/app_localizations.dart';
import 'package:vehicle_damage_analyzer/utils/media_utils.dart';
import 'package:vehicle_damage_analyzer/widgets/vehicle_media_players.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Directory tempHiveDir;

  setUpAll(() async {
    tempHiveDir = await Directory.systemTemp.createTemp('vda_sound_test_hive_');
    Hive.init(tempHiveDir.path);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempHiveDir.path;
      },
    );

    VehicleVideoPlayerCard.disableNativeDecoderForTesting = true;
    VehicleAudioPlayerBar.disableNativeDecoderForTesting = true;
  });

  tearDownAll(() async {
    try {
      await tempHiveDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Vehicle Identity & Specifications Model Tests', () {
    test('VehicleIdentity parses correctly from JSON and serializes back', () {
      final json = {
        'make': 'Toyota',
        'model': 'Hilux Revo',
        'year_range': '2021',
        'body_type': 'Pickup',
        'body_type_km': 'រថយន្តភីកអាប់ (Pickup)',
        'color': 'Metallic White',
        'color_km': 'ពណ៌ស',
        'license_plate': '2AZ-8899',
        'vin': 'MR0HA3CD800123456',
        'odometer_reading': 45200,
      };

      final identity = VehicleIdentity.fromJson(json);
      expect(identity.make, 'Toyota');
      expect(identity.model, 'Hilux Revo');
      expect(identity.yearRange, '2021');
      expect(identity.bodyType, 'Pickup');
      expect(identity.bodyTypeKhmer, 'រថយន្តភីកអាប់ (Pickup)');
      expect(identity.color, 'Metallic White');
      expect(identity.licensePlate, '2AZ-8899');
      expect(identity.vin, 'MR0HA3CD800123456');
      expect(identity.odometerReading, 45200);
      expect(identity.displayName, 'Toyota Hilux Revo 2021');
      expect(identity.isEmpty, isFalse);

      final serialized = identity.toJson();
      expect(serialized['make'], 'Toyota');
      expect(serialized['license_plate'], '2AZ-8899');
      expect(serialized['odometer_reading'], 45200);
    });

    test('VehicleIdentity empty check handles null/empty fields', () {
      const emptyIdentity = VehicleIdentity();
      expect(emptyIdentity.isEmpty, isTrue);
      expect(emptyIdentity.displayName, 'Vehicle (Unidentified)');
    });
  });

  group('Vehicle Health & Roadworthiness Assessment Tests', () {
    test('VehicleHealthAssessment parses scores, grade, and roadworthiness', () {
      final json = {
        'condition_score': 84,
        'condition_grade': 'B',
        'roadworthiness': 'Roadworthy',
        'roadworthiness_km': 'មានសុវត្ថិភាពអាចបើកបរបាន',
        'repair_cost_tier': 'Minor',
        'repair_cost_tier_km': 'ស្រាល (កម្រិតទាប)',
      };

      final health = VehicleHealthAssessment.fromJson(json);
      expect(health.conditionScore, 84);
      expect(health.conditionGrade, 'B');
      expect(health.roadworthiness, 'Roadworthy');
      expect(health.roadworthinessKhmer, 'មានសុវត្ថិភាពអាចបើកបរបាន');
      expect(health.repairCostTier, 'Minor');
    });

    test('KhmerAutomotiveTranslator translates roadworthiness and body types accurately', () {
      expect(KhmerAutomotiveTranslator.roadworthinessKhmer('Roadworthy'),
          'មានសុវត្ថិភាពអាចបើកបរបាន');
      expect(KhmerAutomotiveTranslator.roadworthinessKhmer('Unsafe'),
          'គ្រោះថ្នាក់ មិនគួរដំណើរការ');
      expect(KhmerAutomotiveTranslator.bodyTypeKhmer('Pickup Truck'),
          'រថយន្តភីកអាប់ (Pickup)');
      expect(KhmerAutomotiveTranslator.bodyTypeKhmer('SUV'),
          'រថយន្ត SUV');
      expect(KhmerAutomotiveTranslator.bodyTypeKhmer('Sedan'),
          'រថយន្តទេសចរណ៍ (Sedan)');
    });
  });

  group('Acoustic Sound Analysis Model Tests', () {
    test('AcousticAnalysisResult and AcousticAnomaly parse correctly', () {
      final json = {
        'audio_track_detected': true,
        'acoustic_health_score': 78,
        'engine_sound_profile': 'Belt Squeal & Mild Ticking',
        'engine_sound_profile_km': 'សំឡេងកកិតខ្សែពាន និងរោទិ៍វ៉ាល់ស្រាល',
        'audio_summary': 'Audible high-pitched screech from alternator belt during idle.',
        'audio_summary_km': 'ឮសំឡេងស្រែកកកិតខ្លាំងពីខ្សែពានម៉ាស៊ីនភ្លើងពេលដំណើរការស្ងៀម។',
        'anomalies': [
          {
            'anomaly_type': 'belt_squeal',
            'anomaly_type_km': 'សំឡេងកកិតខ្សែពាន',
            'timestamp_seconds': 3.2,
            'severity': 'moderate',
            'confidence': 0.88,
            'diagnostic_advice': 'Check serpentine belt tensioner and ribbed surface.',
            'diagnostic_advice_km': 'ពិនិត្យតង់ស្យុងខ្សែពាន និងផ្ទៃខ្សែពានម៉ាស៊ីន។',
          },
          {
            'anomaly_type': 'engine_knock',
            'anomaly_type_km': 'សំឡេងគោះក្នុងម៉ាស៊ីន',
            'timestamp_seconds': 7.5,
            'severity': 'severe',
            'confidence': 0.72,
            'diagnostic_advice': 'Inspect rod bearings and engine oil level immediately.',
            'diagnostic_advice_km': 'ពិនិត្យប្រេងម៉ាស៊ីន និងប៊ូសស្យុងរ៉តជាបន្ទាន់។',
          }
        ]
      };

      final acoustic = AcousticAnalysisResult.fromJson(json);
      expect(acoustic.audioTrackDetected, isTrue);
      expect(acoustic.acousticHealthScore, 78);
      expect(acoustic.engineSoundProfile, 'Belt Squeal & Mild Ticking');
      expect(acoustic.anomalies.length, 2);

      final anomaly1 = acoustic.anomalies[0];
      expect(anomaly1.anomalyType, 'belt_squeal');
      expect(anomaly1.timestampSeconds, 3.2);
      expect(anomaly1.severity, DamageSeverity.moderate);
      expect(anomaly1.confidence, 0.88);

      final anomaly2 = acoustic.anomalies[1];
      expect(anomaly2.anomalyType, 'engine_knock');
      expect(anomaly2.severity, DamageSeverity.severe);

      final serialized = acoustic.toJson();
      expect(serialized['audio_track_detected'], isTrue);
      expect(serialized['acoustic_health_score'], 78);
      expect((serialized['anomalies'] as List).length, 2);
    });

    test('KhmerAutomotiveTranslator acousticAnomalyKhmer maps mechanical sounds', () {
      expect(KhmerAutomotiveTranslator.acousticAnomalyKhmer('engine_knock'),
          contains('សំឡេងគោះក្នុងម៉ាស៊ីន'));
      expect(KhmerAutomotiveTranslator.acousticAnomalyKhmer('belt_squeal'),
          contains('សំឡេងកកិតខ្សែពាន'));
      expect(KhmerAutomotiveTranslator.acousticAnomalyKhmer('exhaust_leak'),
          contains('សំឡេងលេចធ្លាយស៊ីមាំង'));
      expect(KhmerAutomotiveTranslator.acousticAnomalyKhmer('brake_squeal'),
          contains('សំឡេងកកិតហ្វ្រាំង'));
    });
  });

  group('DamageReport Full Integration Tests', () {
    test('DamageReport serializes and restores identity, health, and acoustic data', () {
      final report = DamageReport(
        id: 'rep_full_100',
        createdAt: DateTime.now(),
        sourceMediaPath: '/tmp/test.jpg',
        providerLabel: 'Google Gemini',
        modelUsed: 'gemini-2.0-flash',
        items: const [
          DamageItem(
            partName: 'Front Bumper',
            partNameKhmer: 'កាងមុខ',
            damageType: 'dent',
            severity: DamageSeverity.minor,
            confidence: 0.92,
          ),
        ],
        overallConfidence: 0.92,
        vehicleIdentity: const VehicleIdentity(
          make: 'Isuzu',
          model: 'D-Max',
          yearRange: '2020',
          bodyType: 'Pickup',
          licensePlate: '3A-5544',
        ),
        healthAssessment: const VehicleHealthAssessment(
          conditionScore: 88,
          conditionGrade: 'A',
          roadworthiness: 'Roadworthy',
        ),
        acousticAnalysis: const AcousticAnalysisResult(
          audioTrackDetected: true,
          acousticHealthScore: 95,
          engineSoundProfile: 'Normal Smooth Operation',
          engineSoundProfileKhmer: 'ដំណើរការរលូនធម្មតា',
          anomalies: [],
        ),
      );

      final json = report.toJson();
      final restored = DamageReport.fromJson(json);

      expect(restored.vehicleIdentity?.make, 'Isuzu');
      expect(restored.vehicleIdentity?.model, 'D-Max');
      expect(restored.vehicleIdentity?.licensePlate, '3A-5544');
      expect(restored.healthAssessment?.conditionScore, 88);
      expect(restored.healthAssessment?.conditionGrade, 'A');
      expect(restored.acousticAnalysis?.audioTrackDetected, isTrue);
      expect(restored.acousticAnalysis?.acousticHealthScore, 95);
    });
  });

  group('MediaUtils Audio Extraction Tests', () {
    test('MediaUtils extractAudioFromVideo uses customAudioExtractor hook', () async {
      final fakeAudio = File('/tmp/fake_engine.mp3');
      MediaUtils.customAudioExtractor = (videoPath) async => fakeAudio;

      final extracted = await MediaUtils.extractAudioFromVideo('/path/to/engine.mp4');
      expect(extracted, isNotNull);
      expect(extracted!.path, '/tmp/fake_engine.mp3');

      MediaUtils.customAudioExtractor = null;
    });

    test('MediaUtils encodeFileToBase64 encodes dummy file bytes to base64', () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_b64_test_');
      final dummyFile = File('${tempDir.path}/test.txt');
      await dummyFile.writeAsString('AntigravityEngineSoundAudio');

      final b64 = await MediaUtils.encodeFileToBase64(dummyFile);
      expect(b64, isNotEmpty);
      expect(b64, 'QW50aWdyYXZpdHlFbmdpbmVTb3VuZEF1ZGlv');
    });
  });

  group('ReportScreen UI Component Tests', () {
    testWidgets('ReportScreen renders Vehicle Identity, Health Scorecard, and Acoustic Analysis Cards',
        (tester) async {
      final testReport = DamageReport(
        id: 'rep_widget_ui_1',
        createdAt: DateTime.now(),
        sourceMediaPath: '',
        providerLabel: 'Google Gemini',
        modelUsed: 'gemini-2.0-flash',
        summary: 'Vehicle is in good structural condition with normal engine sound.',
        summaryKhmer: 'រថយន្តស្ថិតក្នុងស្ថានភាពល្អ និងសំឡេងម៉ាស៊ីនដំណើរការធម្មតា។',
        items: const [
          DamageItem(
            partName: 'Front Bumper',
            partNameKhmer: 'កាងមុខ',
            damageType: 'dent',
            severity: DamageSeverity.minor,
            confidence: 0.92,
            notes: 'Minor surface dent on left corner.',
            notesKhmer: 'ស្នាមកំពិតស្រាលនៅជ្រុងខាងឆ្វេង។',
          ),
        ],
        overallConfidence: 0.92,
        vehicleIdentity: const VehicleIdentity(
          make: 'Toyota',
          model: 'Hilux Revo',
          yearRange: '2022',
          bodyType: 'Pickup',
          bodyTypeKhmer: 'រថយន្តភីកអាប់ (Pickup)',
          color: 'White',
          colorKhmer: 'ពណ៌ស',
          licensePlate: '2AZ-8899',
          vin: 'MR0HA3CD800123456',
          odometerReading: 34500,
        ),
        healthAssessment: const VehicleHealthAssessment(
          conditionScore: 86,
          conditionGrade: 'B',
          roadworthiness: 'Roadworthy',
          roadworthinessKhmer: 'មានសុវត្ថិភាពអាចបើកបរបាន',
          repairCostTier: 'Minor',
          repairCostTierKhmer: 'ស្រាល (កម្រិតទាប)',
        ),
        acousticAnalysis: const AcousticAnalysisResult(
          audioTrackDetected: true,
          acousticHealthScore: 82,
          engineSoundProfile: 'Belt Squeal Detected',
          engineSoundProfileKhmer: 'រកឃើញសំឡេងកកិតខ្សែពាន',
          audioSummary: 'High pitch belt squeak noted at idle.',
          audioSummaryKhmer: 'ឮសំឡេងស្រែកកកិតខ្សែពានពេលម៉ាស៊ីនដំណើរការស្ងៀម។',
          anomalies: [
            AcousticAnomaly(
              anomalyType: 'belt_squeal',
              anomalyTypeKhmer: 'សំឡេងកកិតខ្សែពាន',
              timestampSeconds: 2.4,
              severity: DamageSeverity.minor,
              confidence: 0.85,
              diagnosticAdvice: 'Check serpentine belt.',
              diagnosticAdviceKhmer: 'ពិនិត្យខ្សែពានម៉ាស៊ីន។',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportScreen(report: testReport),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Vehicle Identity Card elements
      expect(find.text('Toyota Hilux Revo 2022'), findsOneWidget);
      expect(find.text('2AZ-8899'), findsOneWidget);
      expect(find.text('VIN: MR0HA3CD800123456'), findsOneWidget);
      expect(find.text('34,500 km'), findsOneWidget);

      // 2. Verify Health Scorecard elements
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Grade B'), findsOneWidget);
      expect(find.text('មានសុវត្ថិភាពអាចបើកបរបាន'), findsOneWidget);

      // 3. Verify Acoustic Analysis Card elements (collapsed by default)
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('រកឃើញសំឡេងកកិតខ្សែពាន'), findsOneWidget);

      // Expand acoustic card to view anomalies & Listen buttons
      await tester.tap(find.byKey(const Key('toggle_acoustic_analysis_card')));
      await tester.pumpAndSettle();

      expect(find.text('2.4s'), findsOneWidget);
      expect(find.text('ពិនិត្យខ្សែពានម៉ាស៊ីន។'), findsOneWidget);
      expect(find.byKey(const Key('listen_sound_anomaly_0_km')), findsOneWidget);
      expect(find.byKey(const Key('listen_sound_anomaly_0_en')), findsOneWidget);
    });

    testWidgets('ReportScreen renders Detected via Sound badge on acoustic defect items',
        (tester) async {
      final acousticReport = DamageReport(
        id: 'rep_acoustic_items_test',
        createdAt: DateTime.now(),
        sourceMediaPath: '',
        providerLabel: 'Google Gemini',
        modelUsed: 'gemini-2.0-flash',
        items: const [
          DamageItem(
            partName: 'Engine Bay (Sound)',
            partNameKhmer: 'ផ្នែកម៉ាស៊ីន (សំឡេង)',
            damageType: 'engine_knock',
            severity: DamageSeverity.severe,
            confidence: 0.89,
            notes: '[Detected via Sound 🔊] Rod knock detected at 2500 RPM.',
            notesKhmer: '[រកឃើញតាមរយៈសំឡេង 🔊] សំឡេងគោះម៉ាស៊ីនពេលសង្កត់ហ្គែរ។',
          ),
        ],
        overallConfidence: 0.89,
        acousticAnalysis: const AcousticAnalysisResult(
          audioTrackDetected: true,
          acousticHealthScore: 65,
          engineSoundProfile: 'Engine Knock Detected',
          engineSoundProfileKhmer: 'រកឃើញសំឡេងគោះក្នុងម៉ាស៊ីន',
          anomalies: [
            AcousticAnomaly(
              anomalyType: 'engine_knock',
              anomalyTypeKhmer: 'សំឡេងគោះក្នុងម៉ាស៊ីន',
              timestampSeconds: 3.1,
              severity: DamageSeverity.severe,
              confidence: 0.89,
              diagnosticAdvice: 'Inspect engine bottom end.',
              diagnosticAdviceKhmer: 'ពិនិត្យប្រព័ន្ធម៉ាស៊ីនខាងក្នុងជាបន្ទាន់។',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportScreen(report: acousticReport),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Acoustic Card at top before scrolling
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('រកឃើញសំឡេងគោះក្នុងម៉ាស៊ីន'), findsOneWidget);

      // Scroll to defect item card in vertical ListView
      final soundBadgeFinder = find.text('រកឃើញតាមសំឡេង 🔊');
      await tester.scrollUntilVisible(
        soundBadgeFinder,
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(soundBadgeFinder, findsOneWidget);
      expect(find.text('ផ្នែកម៉ាស៊ីន (សំឡេង)'), findsOneWidget);
    });

    testWidgets('ReportScreen handles audioTrackDetected = false gracefully',
        (tester) async {
      final silentReport = DamageReport(
        id: 'rep_silent_test',
        createdAt: DateTime.now(),
        sourceMediaPath: '',
        providerLabel: 'Google Gemini',
        modelUsed: 'gemini-2.0-flash',
        items: const [],
        overallConfidence: 0.95,
        acousticAnalysis: const AcousticAnalysisResult(
          audioTrackDetected: false,
          acousticHealthScore: 100,
          engineSoundProfile: 'No Audio Track',
          engineSoundProfileKhmer: 'មិនមានសំឡេងក្នុងវីដេអូ',
          anomalies: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportScreen(report: silentReport),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('មិនឮសំឡេងម៉ាស៊ីនច្បាស់ក្នុងវីដេអូ'), findsOneWidget);
    });

    testWidgets('ReportScreen defaults Vehicle Inspection Video and Sound Analysis to collapsed, and supports Listen KH/EN for anomalies',
        (tester) async {
      final fakeVideoFile = File('${Directory.systemTemp.path}/test_vda_collapsible.mp4');
      fakeVideoFile.writeAsBytesSync([1, 2, 3]);

      try {
        final report = DamageReport(
          id: 'rep_media_collapse_test',
          createdAt: DateTime.now(),
          sourceMediaPath: fakeVideoFile.path,
          videoPath: fakeVideoFile.path,
          providerLabel: 'SV Backend',
          modelUsed: 'multimodal-vehicle-analyzer',
          items: const [],
          overallConfidence: 0.94,
          acousticAnalysis: const AcousticAnalysisResult(
            audioTrackDetected: true,
            acousticHealthScore: 78,
            engineSoundProfile: 'Belt Squeal',
            engineSoundProfileKhmer: 'សំឡេងកកិតខ្សែពាន',
            audioSummary: 'Serpentine belt slipping detected.',
            audioSummaryKhmer: 'រកឃើញសំឡេងកកិតខ្សែពានម៉ាស៊ីន។',
            anomalies: [
              AcousticAnomaly(
                anomalyType: 'belt_squeal',
                anomalyTypeKhmer: 'សំឡេងកកិតខ្សែពាន',
                timestampSeconds: 1.5,
                severity: DamageSeverity.moderate,
                confidence: 0.91,
                diagnosticAdvice: 'Inspect belt tensioner.',
                diagnosticAdviceKhmer: 'ពិនិត្យរ៉កតង់ស្យុងខ្សែពាន។',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ReportScreen(report: report),
            ),
          ),
        );
        await tester.pump();

        // 1. Verify Vehicle Inspection Video is collapsed by default
        expect(find.text('វីដេអូត្រួតពិនិត្យរថយន្ត'), findsOneWidget);
        expect(find.text('ចុចដើម្បីមើលវីដេអូ'), findsOneWidget);
        expect(find.byType(VehicleVideoPlayerCard), findsNothing);

        // Expand Vehicle Inspection Video
        await tester.tap(find.byKey(const Key('toggle_inspection_video_collapse_button')));
        await tester.pump();
        expect(find.text('ចុចដើម្បីបង្រួម'), findsOneWidget);
        expect(find.byType(VehicleVideoPlayerCard), findsOneWidget);

        // 2. Verify Sound Analysis Card is collapsed by default
        expect(find.text('78%'), findsOneWidget);
        expect(find.text('សំឡេងកកិតខ្សែពាន'), findsOneWidget);
        expect(find.text('ចុចដើម្បីមើលការវិភាគសំឡេងលម្អិត'), findsOneWidget);
        expect(find.text('1.5s'), findsNothing);
        expect(find.byKey(const Key('listen_sound_anomaly_0_km')), findsNothing);

        // Expand Sound Analysis Card
        await tester.tap(find.byKey(const Key('toggle_acoustic_analysis_card')));
        await tester.pump();

        expect(find.text('1.5s'), findsOneWidget);
        expect(find.text('ពិនិត្យរ៉កតង់ស្យុងខ្សែពាន។'), findsOneWidget);

        // 3. Verify Listen Khmer and Listen English buttons exist for detected anomalies
        final listenKmFinder = find.byKey(const Key('listen_sound_anomaly_0_km'));
        final listenEnFinder = find.byKey(const Key('listen_sound_anomaly_0_en'));
        expect(listenKmFinder, findsOneWidget);
        expect(listenEnFinder, findsOneWidget);
        expect(find.text('ស្ដាប់ខ្មែរ'), findsOneWidget);
        expect(find.text('Listen EN'), findsOneWidget);
      } finally {
        if (fakeVideoFile.existsSync()) {
          fakeVideoFile.deleteSync();
        }
      }
    });
  });

  group('CaptureScreen Audio Checkbox Tests', () {
    testWidgets('CaptureScreen renders analyze_with_audio_checkbox in options modal and toggles state',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaptureScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open inspection options modal via button
      final openButtonFinder =
          find.byKey(const Key('open_inspection_scope_modal_button'));
      expect(openButtonFinder, findsOneWidget);
      await tester.tap(openButtonFinder);
      await tester.pumpAndSettle();

      final checkboxFinder =
          find.byKey(const Key('analyze_with_audio_checkbox'));
      expect(checkboxFinder, findsOneWidget);

      // Verify initial state is checked
      final initialCheckbox =
          tester.widget<CheckboxListTile>(checkboxFinder);
      expect(initialCheckbox.value, isTrue);

      // Tap to uncheck
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final toggledCheckbox =
          tester.widget<CheckboxListTile>(checkboxFinder);
      expect(toggledCheckbox.value, isFalse);

      // Close modal by tapping Done
      await tester.tap(find.byKey(const Key('apply_inspection_scope_button')));
      await tester.pumpAndSettle();

      // Verify redundant status capsule labels are removed from main screen card
      expect(find.text('សំឡេង: បិទ'), findsNothing);
      expect(find.text('Audio: Active'), findsNothing);

      // Re-open modal to verify audio toggle state persisted
      await tester.tap(find.byKey(const Key('open_inspection_scope_modal_button')));
      await tester.pumpAndSettle();
      final reopenedCheckbox =
          tester.widget<CheckboxListTile>(checkboxFinder);
      expect(reopenedCheckbox.value, isFalse);
    });
  });

  group('DamageReport Video & Audio Playback and Persistence Tests', () {
    test('DamageReport serializes and deserializes videoPath and audioPath', () {
      final now = DateTime.now();
      final report = DamageReport(
        id: 'rep_media_persist_test',
        createdAt: now,
        sourceMediaPath: '/media/photo.jpg',
        mediaPaths: const ['/media/photo.jpg'],
        providerLabel: 'Google Gemini',
        modelUsed: 'gemini-2.0-flash',
        items: const [],
        overallConfidence: 0.95,
        videoPath: '/data/vda_report_media/video_rep_media_persist_test.mp4',
        audioPath: '/data/vda_report_media/audio_rep_media_persist_test.m4a',
      );

      expect(report.videoPath,
          '/data/vda_report_media/video_rep_media_persist_test.mp4');
      expect(report.audioPath,
          '/data/vda_report_media/audio_rep_media_persist_test.m4a');
      expect(report.allAssociatedFilePaths, contains(report.videoPath));
      expect(report.allAssociatedFilePaths, contains(report.audioPath));

      final json = report.toJson();
      expect(json['videoPath'],
          '/data/vda_report_media/video_rep_media_persist_test.mp4');
      expect(json['audioPath'],
          '/data/vda_report_media/audio_rep_media_persist_test.m4a');

      final reconstructed = DamageReport.fromJson(json);
      expect(reconstructed.videoPath, report.videoPath);
      expect(reconstructed.audioPath, report.audioPath);
    });

    test('MediaUtils persistReportVideo and persistReportAudio copy files to storage',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('vda_media_test_');
      final dummyVideo = File('${tempDir.path}/test_source.mp4');
      await dummyVideo.writeAsString('dummy mp4 content');
      final dummyAudio = File('${tempDir.path}/test_source.m4a');
      await dummyAudio.writeAsString('dummy m4a content');

      final persistedVideo =
          await MediaUtils.persistReportVideo(dummyVideo, 'test_id_123');
      final persistedAudio =
          await MediaUtils.persistReportAudio(dummyAudio, 'test_id_123');

      expect(persistedVideo, isNotNull);
      expect(File(persistedVideo!).existsSync(), isTrue);
      expect(persistedVideo, contains('video_test_id_123.mp4'));

      expect(persistedAudio, isNotNull);
      expect(File(persistedAudio!).existsSync(), isTrue);
      expect(persistedAudio, contains('audio_test_id_123.m4a'));

      // Clean up
      await MediaUtils.deleteReportMedia([persistedVideo, persistedAudio]);
      expect(File(persistedVideo).existsSync(), isFalse);
      expect(File(persistedAudio).existsSync(), isFalse);
      await tempDir.delete(recursive: true);
    });

    testWidgets('VehicleVideoPlayerCard and VehicleAudioPlayerBar render together in report view',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VehicleVideoPlayerCard(
                  videoPath: '/path/to/test.mp4',
                  title: 'វីដេអូត្រួតពិនិត្យរថយន្ត',
                ),
                VehicleAudioPlayerBar(
                  audioPath: '/path/to/test.m4a',
                  title: 'Play Extracted Audio',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('វីដេអូត្រួតពិនិត្យរថយន្ត'), findsOneWidget);
      expect(find.byKey(const Key('toggle_audio_playback_button')),
          findsOneWidget);
      expect(find.text('Play Extracted Audio'), findsOneWidget);
    });
  });
}
