import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:vehicle_damage_analyzer/models/ai_provider_config.dart';
import 'package:vehicle_damage_analyzer/models/damage_report.dart';
import 'package:vehicle_damage_analyzer/providers/app_state.dart';
import 'package:vehicle_damage_analyzer/screens/report_screen.dart';
import 'package:vehicle_damage_analyzer/screens/settings_screen.dart';
import 'package:vehicle_damage_analyzer/services/config_service.dart';
import 'package:vehicle_damage_analyzer/utils/app_localizations.dart';
import 'package:vehicle_damage_analyzer/utils/auto_part_cropper.dart';
import 'package:vehicle_damage_analyzer/widgets/part_crop_viewer.dart';

class FakeConfigService extends ConfigService {
  AIProviderConfig? _config;
  FakeConfigService([this._config]);

  @override
  Future<void> save(AIProviderConfig config) async {
    _config = config;
  }

  @override
  Future<AIProviderConfig?> load() async {
    return _config;
  }

  @override
  Future<void> clear() async {
    _config = null;
  }
}

class _TestLanguageNotifier extends AppLanguageNotifier {
  _TestLanguageNotifier(AppLanguage lang) : super() {
    state = lang;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('auto_crop_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  File createTestImageFile(String name, {int width = 300, int height = 200}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgba(x, y, 50, (x % 255), (y % 255), 255);
      }
    }
    final bytes = img.encodeJpg(image, quality: 80);
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('BoundingBox Model Tests', () {
    test('parses 0-1000 scale list (Gemini / box_2d convention)', () {
      final box = BoundingBox.fromDynamic([620, 160, 890, 420]);
      expect(box, isNotNull);
      expect(box!.ymin, closeTo(0.62, 0.001));
      expect(box.xmin, closeTo(0.16, 0.001));
      expect(box.ymax, closeTo(0.89, 0.001));
      expect(box.xmax, closeTo(0.42, 0.001));
      expect(box.isValid, isTrue);
      expect(box.to1000List(), equals([620, 160, 890, 420]));
    });

    test('parses normalized 0.0-1.0 float scale list', () {
      final box = BoundingBox.fromDynamic([0.25, 0.10, 0.75, 0.85]);
      expect(box, isNotNull);
      expect(box!.ymin, equals(0.25));
      expect(box.xmin, equals(0.10));
      expect(box.ymax, equals(0.75));
      expect(box.xmax, equals(0.85));
      expect(box.isValid, isTrue);
    });

    test('parses Map with coordinates', () {
      final box = BoundingBox.fromDynamic({
        'ymin': 0.15,
        'xmin': 0.20,
        'ymax': 0.65,
        'xmax': 0.80,
      });
      expect(box, isNotNull);
      expect(box!.ymin, equals(0.15));
      expect(box.width, closeTo(0.60, 0.001));
      expect(box.height, closeTo(0.50, 0.001));
    });

    test('handles invalid or empty dynamic values gracefully', () {
      expect(BoundingBox.fromDynamic(null), isNull);
      expect(BoundingBox.fromDynamic([]), isNull);
      expect(BoundingBox.fromDynamic([1, 2]), isNull);
      expect(BoundingBox.fromDynamic('not-a-box'), isNull);
    });

    test('toPixelRect accurately calculates image pixel bounding rect', () {
      const box = BoundingBox(ymin: 0.1, xmin: 0.2, ymax: 0.5, xmax: 0.6);
      final rect = box.toPixelRect(1000, 500);
      expect(rect.left, equals(200.0));
      expect(rect.top, equals(50.0));
      expect(rect.right, equals(600.0));
      expect(rect.bottom, equals(250.0));
      expect(rect.width, equals(400.0));
      expect(rect.height, equals(200.0));
    });
  });

  group('DamageItem Component Classification & Serialization Tests', () {
    test('identifies Tires and classifies component category accurately', () {
      const tireItem = DamageItem(
        partName: 'Front Left Tire',
        partNameKhmer: 'សំបកកង់ខាងឆ្វេងមុខ',
        damageType: 'tire_damage',
        severity: DamageSeverity.moderate,
        confidence: 0.92,
        boundingBox: BoundingBox(ymin: 0.6, xmin: 0.15, ymax: 0.9, xmax: 0.45),
      );

      expect(tireItem.isTire, isTrue);
      expect(tireItem.isHydraulic, isFalse);
      expect(tireItem.hasCrop, isTrue);
      expect(tireItem.componentCategory(isKhmer: false), equals('Tire & Wheel'));
      expect(tireItem.componentCategory(isKhmer: true), equals('កង់ និងសំបកកង់'));
    });

    test('identifies Hydraulic system and classifies component category accurately', () {
      const hydraulicItem = DamageItem(
        partName: 'Hydraulic Steering Cylinder & Hose',
        partNameKhmer: 'បូមជំនួយចង្កូត និងទុយោអ៊ីដ្រូលីក',
        damageType: 'hydraulic_fault',
        severity: DamageSeverity.severe,
        confidence: 0.88,
        boundingBox: BoundingBox(ymin: 0.4, xmin: 0.45, ymax: 0.7, xmax: 0.75),
      );

      expect(hydraulicItem.isHydraulic, isTrue);
      expect(hydraulicItem.isTire, isFalse);
      expect(hydraulicItem.hasCrop, isTrue);
      expect(hydraulicItem.componentCategory(isKhmer: false), equals('Hydraulic System'));
      expect(hydraulicItem.componentCategory(isKhmer: true), equals('ប្រព័ន្ធអ៊ីដ្រូលីក'));
    });

    test('serializes bounding box and cropped path to JSON and restores back', () {
      const item = DamageItem(
        partName: 'Front Left Tire',
        partNameKhmer: 'សំបកកង់ខាងឆ្វេងមុខ',
        damageType: 'tire_damage',
        severity: DamageSeverity.moderate,
        confidence: 0.89,
        boundingBox: BoundingBox(ymin: 0.62, xmin: 0.16, ymax: 0.89, xmax: 0.42),
        imageIndex: 1,
        croppedImagePath: '/data/crops/crop_0_tire.jpg',
      );

      final json = item.toJson();
      expect(json['box_2d'], equals([620, 160, 890, 420]));
      expect(json['image_index'], equals(1));
      expect(json['cropped_image_path'], equals('/data/crops/crop_0_tire.jpg'));

      final restored = DamageItem.fromJson(json);
      expect(restored.partName, equals('Front Left Tire'));
      expect(restored.boundingBox, isNotNull);
      expect(restored.boundingBox!.ymin, closeTo(0.62, 0.001));
      expect(restored.imageIndex, equals(1));
      expect(restored.croppedImagePath, equals('/data/crops/crop_0_tire.jpg'));
    });
  });

  group('AutoPartCropper Utility Tests', () {
    test('cropPartFromImage crops sub-region and saves valid JPEG', () async {
      final sourceFile = createTestImageFile('source_car.jpg', width: 400, height: 300);
      final outPath = p.join(tempDir.path, 'cropped_tire.jpg');

      const box = BoundingBox(ymin: 0.4, xmin: 0.1, ymax: 0.8, xmax: 0.5);
      final resultPath = await AutoPartCropper.cropPartFromImage(
        sourceImageFile: sourceFile,
        box: box,
        outputFilePath: outPath,
        paddingRatio: 0.10,
      );

      expect(resultPath, isNotNull);
      expect(File(resultPath!).existsSync(), isTrue);

      final croppedBytes = File(resultPath).readAsBytesSync();
      final decodedCrop = img.decodeImage(croppedBytes);
      expect(decodedCrop, isNotNull);
      expect(decodedCrop!.width, greaterThan(0));
      expect(decodedCrop.height, greaterThan(0));
      expect(decodedCrop.width, lessThan(400));
    });

    test('cropReportParts iterates report items and populates croppedImagePath', () async {
      final sourceFile = createTestImageFile('report_car_photo.jpg', width: 400, height: 300);
      final cropsDir = Directory(p.join(tempDir.path, 'report_crops'));

      final report = DamageReport(
        id: 'test_report_crop_1',
        createdAt: DateTime.now(),
        sourceMediaPath: sourceFile.path,
        mediaPaths: [sourceFile.path],
        providerLabel: 'Custom Provider',
        modelUsed: 'multimodal-inspect',
        items: const [
          DamageItem(
            partName: 'Front Left Tire',
            partNameKhmer: 'សំបកកង់ខាងឆ្វេងមុខ',
            damageType: 'tire_damage',
            severity: DamageSeverity.moderate,
            confidence: 0.93,
            boundingBox: BoundingBox(ymin: 0.5, xmin: 0.15, ymax: 0.85, xmax: 0.45),
            imageIndex: 0,
          ),
          DamageItem(
            partName: 'Hydraulic Steering Hose',
            partNameKhmer: 'ទុយោជំនួយចង្កូតអ៊ីដ្រូលីក',
            damageType: 'hydraulic_fault',
            severity: DamageSeverity.severe,
            confidence: 0.89,
            boundingBox: BoundingBox(ymin: 0.35, xmin: 0.5, ymax: 0.65, xmax: 0.8),
            imageIndex: 0,
          ),
        ],
        overallConfidence: 0.91,
      );

      final croppedReport = await AutoPartCropper.cropReportParts(
        report,
        targetDir: cropsDir,
      );

      expect(croppedReport.items.length, equals(2));
      expect(croppedReport.items[0].croppedImagePath, isNotNull);
      expect(File(croppedReport.items[0].croppedImagePath!).existsSync(), isTrue);

      expect(croppedReport.items[1].croppedImagePath, isNotNull);
      expect(File(croppedReport.items[1].croppedImagePath!).existsSync(), isTrue);
    });
  });

  group('ReportScreen UI & Zoom Dialog Tests', () {
    testWidgets('ReportScreen renders PartCropThumbnail and opens Part Crop Zoom dialog on tap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testImage = createTestImageFile('ui_car_test.jpg', width: 400, height: 300);
      final croppedTire = createTestImageFile('ui_tire_crop.jpg', width: 150, height: 150);

      final report = DamageReport(
        id: 'ui_crop_report',
        createdAt: DateTime.now(),
        sourceMediaPath: testImage.path,
        mediaPaths: [testImage.path],
        providerLabel: 'AI Multimodal Vision',
        modelUsed: 'gemini-2.0-flash',
        items: [
          DamageItem(
            partName: 'Front Left Tire',
            partNameKhmer: 'សំបកកង់ខាងឆ្វេងមុខ',
            damageType: 'tire_damage',
            damageTypeKhmer: 'សំបកកង់សឹក និងប្រេះ',
            severity: DamageSeverity.moderate,
            confidence: 0.92,
            boundingBox: const BoundingBox(ymin: 0.5, xmin: 0.1, ymax: 0.85, xmax: 0.4),
            imageIndex: 0,
            croppedImagePath: croppedTire.path,
            notes: 'Tread depth is worn down to 3mm with sidewall curb rash.',
            notesKhmer: 'កម្រាស់ក្រឡាកង់នៅសល់ 3mm និងមានស្នាមកកិតគែមចំហៀង។',
          ),
        ],
        overallConfidence: 0.92,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((ref) => _TestLanguageNotifier(AppLanguage.en)),
          ],
          child: MaterialApp(
            home: ReportScreen(report: report),
          ),
        ),
      );
      await tester.pump();

      // Find the PartCropThumbnail on the defect card
      expect(find.byType(PartCropThumbnail), findsOneWidget);
      expect(find.text('Auto Crop'), findsOneWidget);
      expect(find.text('Tire & Wheel'), findsOneWidget);

      // Tap on the crop thumbnail to open the interactive inspection dialog
      await tester.tap(find.byType(PartCropThumbnail));
      await tester.pump();

      // Dialog should now be open
      expect(find.text('Cropped Part'), findsOneWidget);
      expect(find.text('Vehicle Context'), findsOneWidget);

      // Switch to Vehicle Context Tab
      await tester.tap(find.text('Vehicle Context'));
      await tester.pump();

      // Close the dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Dialog dismissed
      expect(find.text('Vehicle Context'), findsNothing);
    });

    testWidgets('PartCropThumbnail respects autoCropPartsProvider and hides when setting is disabled',
        (tester) async {
      final testImage = createTestImageFile('ui_crop_disabled.jpg', width: 400, height: 300);
      final croppedTire = createTestImageFile('ui_tire_crop_dis.jpg', width: 150, height: 150);

      final report = DamageReport(
        id: 'ui_crop_report_disabled',
        createdAt: DateTime.now(),
        sourceMediaPath: testImage.path,
        mediaPaths: [testImage.path],
        providerLabel: 'AI Multimodal Vision',
        modelUsed: 'gemini-2.0-flash',
        items: [
          DamageItem(
            partName: 'Front Left Tire',
            partNameKhmer: 'សំបកកង់ខាងឆ្វេងមុខ',
            damageType: 'tire_damage',
            severity: DamageSeverity.moderate,
            confidence: 0.92,
            boundingBox: const BoundingBox(ymin: 0.5, xmin: 0.1, ymax: 0.85, xmax: 0.4),
            imageIndex: 0,
            croppedImagePath: croppedTire.path,
          ),
        ],
        overallConfidence: 0.92,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((ref) => _TestLanguageNotifier(AppLanguage.en)),
            autoCropPartsProvider.overrideWith((ref) => AutoCropPartsNotifier()..state = false),
          ],
          child: MaterialApp(
            home: ReportScreen(report: report),
          ),
        ),
      );
      await tester.pump();

      // When auto-crop is disabled, the crop thumbnail should be hidden
      expect(find.byType(PartCropThumbnail), findsNothing);
    });

    testWidgets('SettingsScreen renders Auto-Crop parts switch and toggles user preference',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late ProviderContainer container;
      final fakeConfigService = FakeConfigService(
        const AIProviderConfig(
          kind: AIProviderKind.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          apiKey: 'AIzaSyFakeKey',
          model: 'gemini-1.5-flash',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configServiceProvider.overrideWithValue(fakeConfigService),
            appLanguageProvider.overrideWith((ref) => _TestLanguageNotifier(AppLanguage.en)),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: SettingsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the auto-crop parts switch tile
      final switchFinder = find.byKey(const Key('settings_auto_crop_parts_switch'));
      expect(switchFinder, findsOneWidget);

      // Verify default state is true (enabled)
      expect(container.read(autoCropPartsProvider), isTrue);

      // Tap the switch to toggle it
      await tester.tap(switchFinder);
      await tester.pump();

      // Preference should now be false (disabled)
      expect(container.read(autoCropPartsProvider), isFalse);
    });

    test('Vehicle Context applyBoxFit accurately isolates letterboxing for non-square images', () {
      // Natural landscape image 800x600 (aspect 1.333) inside portrait container 400x500 (aspect 0.8)
      const naturalImageSize = Size(800, 600);
      const containerSize = Size(400, 500);

      final fittedSizes = applyBoxFit(BoxFit.contain, naturalImageSize, containerSize);
      expect(fittedSizes.destination.width, equals(400.0));
      expect(fittedSizes.destination.height, equals(300.0));

      final imageRect = Alignment.center.inscribe(
        fittedSizes.destination,
        Offset.zero & containerSize,
      );

      // The destination rectangle is vertically centered with 100px letterbox on top & bottom
      expect(imageRect.left, equals(0.0));
      expect(imageRect.top, equals(100.0));
      expect(imageRect.width, equals(400.0));
      expect(imageRect.height, equals(300.0));

      // Cab roof header at ymin=0.10, ymax=0.30
      const box = BoundingBox(ymin: 0.10, xmin: 0.20, ymax: 0.30, xmax: 0.80);
      final pixelTop = box.ymin * imageRect.height;
      final pixelHeight = (box.ymax - box.ymin) * imageRect.height;

      // Relative to the image itself, top is exactly 30px from image top, height is 60px
      expect(pixelTop, closeTo(30.0, 0.001));
      expect(pixelHeight, closeTo(60.0, 0.001));
    });
  });
}
