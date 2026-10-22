import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:vehicle_damage_analyzer/models/ai_provider_config.dart';
import 'package:vehicle_damage_analyzer/models/damage_report.dart';
import 'package:vehicle_damage_analyzer/providers/app_state.dart';
import 'package:vehicle_damage_analyzer/screens/capture_screen.dart';
import 'package:vehicle_damage_analyzer/screens/history_screen.dart';
import 'package:vehicle_damage_analyzer/screens/report_screen.dart';
import 'package:vehicle_damage_analyzer/screens/settings_screen.dart';
import 'package:vehicle_damage_analyzer/services/config_service.dart';
import 'package:vehicle_damage_analyzer/services/history_service.dart';
import 'package:vehicle_damage_analyzer/services/tts_service.dart';
import 'package:vehicle_damage_analyzer/utils/app_localizations.dart';
import 'package:vehicle_damage_analyzer/utils/media_utils.dart';
import 'package:image/image.dart' as img;

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

class FakeHistoryService extends HistoryService {
  final List<DamageReport> _reports;
  FakeHistoryService([List<DamageReport>? initial])
      : _reports = List<DamageReport>.from(initial ?? const []);

  @override
  Future<void> save(DamageReport report) async {
    _reports.removeWhere((r) => r.id == report.id);
    _reports.insert(0, report);
  }

  @override
  Future<List<DamageReport>> loadAll() async => List.unmodifiable(_reports);

  @override
  Future<void> delete(String id) async {
    _reports.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearAll() async {
    _reports.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init(
        '${Directory.systemTemp.path}/vda_test_${DateTime.now().millisecondsSinceEpoch}');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('AIProviderConfig tests', () {
    test('defaults and suggestedModels for each provider', () {
      for (final kind in AIProviderKind.values) {
        final config = AIProviderConfig.defaultsFor(kind);
        expect(config.kind, equals(kind));
        expect(config.model, isNotEmpty);
        expect(kind.suggestedModels, isNotEmpty);
        expect(kind.suggestedModels, contains(config.model));
        if (kind != AIProviderKind.custom) {
          expect(config.baseUrl, isNotEmpty);
        }
      }
    });

    test('isValid check requires apiKey for commercial providers', () {
      const openaiWithoutKey = AIProviderConfig(
        kind: AIProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: '',
        model: 'gpt-4o-mini',
      );
      expect(openaiWithoutKey.isValid, isFalse);

      final openaiWithKey = openaiWithoutKey.copyWith(apiKey: 'sk-test123');
      expect(openaiWithKey.isValid, isTrue);

      const customWithoutKey = AIProviderConfig(
        kind: AIProviderKind.custom,
        baseUrl: 'http://localhost:11434/v1',
        apiKey: '',
        model: 'llama-3.2-11b-vision-instruct',
      );
      expect(customWithoutKey.isValid, isTrue);
    });
  });

  group('MediaUtils image optimization test', () {
    test('downscales large images in isolate and compresses to JPEG', () async {
      final testImg = img.Image(width: 1600, height: 1200);
      img.fill(testImg, color: img.ColorRgb8(255, 0, 0));
      final rawBytes = img.encodeJpg(testImg);

      final stagingDir = await MediaUtils.stagingDir();
      final tempFile = File('${stagingDir.path}/test_raw_image.jpg');
      await tempFile.writeAsBytes(rawBytes);

      final optimized =
          await MediaUtils.optimizeImage(tempFile, maxDimension: 1000);
      expect(optimized.existsSync(), isTrue);

      final decodedOpt = img.decodeImage(await optimized.readAsBytes());
      expect(decodedOpt, isNotNull);
      expect(decodedOpt!.width, lessThanOrEqualTo(1000));
      expect(decodedOpt.height, lessThanOrEqualTo(1000));

      final encodedB64 = await MediaUtils.encodeImagesToBase64([optimized]);
      expect(encodedB64.length, equals(1));
      expect(encodedB64.first, isNotEmpty);

      await MediaUtils.clearStaging();
    });
  });

  group('SettingsScreen widget test', () {
    testWidgets('displays provider grid and model dropdown in Khmer and English',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Default locale is Khmer
      expect(find.text('ការកំណត់ប្រព័ន្ធ AI'), findsOneWidget);
      expect(find.text('ក្រុមហ៊ុនផ្តល់សេវា AI'), findsOneWidget);
      expect(find.text('ជ្រើសរើសម៉ូដែល AI'), findsOneWidget);
      expect(find.text('ទាញយកបញ្ជីម៉ូដែល'), findsOneWidget);
      expect(find.byKey(const Key('settings_inspection_scope_tile')), findsOneWidget);
      expect(find.text('រក្សាទុកការកំណត់'), findsOneWidget);

      // Toggle to English
      await tester.tap(find.text('ខ្មែរ'));
      await tester.pump();

      expect(find.text('AI Engine Configuration'), findsOneWidget);
      expect(find.text('AI Vision Provider'), findsOneWidget);
      expect(find.text('Model Selection'), findsOneWidget);
      expect(find.byKey(const Key('settings_inspection_scope_tile')), findsOneWidget);
      expect(find.text('Load Models'), findsOneWidget);
      expect(find.text('Save Settings'), findsOneWidget);
    });
  });

  group('CaptureScreen widget test', () {
    testWidgets(
        'displays clean Khmer and English UI without duplicate labels and focus chips do not overwrite manual notes',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeConfigService = FakeConfigService(
        const AIProviderConfig(
          kind: AIProviderKind.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          apiKey: 'AIzaSyFakeKey',
          model: 'gemini-2.0-flash',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configServiceProvider.overrideWithValue(fakeConfigService),
          ],
          child: const MaterialApp(
            home: CaptureScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify clean Khmer labels on CaptureScreen (default locale)
      expect(find.text('SV - ពិនិត្យកំហុស និងការខូចខាតរថយន្ត'), findsOneWidget);
      expect(find.text('ថតរូបភាព'), findsOneWidget);
      expect(find.text('ជ្រើសរើសរូបភាព'), findsOneWidget);
      expect(find.text('គោលដៅត្រួតពិនិត្យ និងប្រភេទកំហុស'), findsOneWidget);
      expect(find.text('រថយន្តទាំងមូល'), findsOneWidget);
      expect(find.text('កំណត់ជម្រើស'), findsOneWidget);
      expect(find.text('ចាប់ផ្តើមវិភាគកំហុស និងការខូចខាតរថយន្ត'), findsOneWidget);

      // Open the options modal bottom sheet via click button
      await tester.tap(find.byKey(const Key('open_inspection_scope_modal_button')));
      await tester.pumpAndSettle();

      // Type custom incident notes inside the modal
      await tester.enterText(
          find.byType(TextField), 'Front bumper parking scrape');
      await tester.pump();

      // Verify modal content
      expect(find.text('តំបន់រថយន្ត'), findsOneWidget);
      expect(find.text('ម៉ាស៊ីន និងប្រព័ន្ធមេកានិច'), findsOneWidget);
      expect(find.text('ប្រភេទការខូចខាត'), findsOneWidget);
      expect(find.text('ដកចេញទាំងអស់'), findsOneWidget);
      expect(find.text('កំហុសម៉ាស៊ីន និងមេកានិច'), findsOneWidget);
      expect(find.text('លេចធ្លាយប្រេង / ទឹកស្អំ'), findsOneWidget);
      expect(find.text('ស្នាមកំពិត និងផត'), findsOneWidget);
      expect(find.text('ស្នាមឆ្កូតជ្រៅ'), findsOneWidget);

      // Deselect one tag
      await tester.tap(find.text('កំហុសម៉ាស៊ីន និងមេកានិច'));
      await tester.pump();
      expect(find.text('ជ្រើសរើសទាំងអស់'), findsOneWidget);

      // Close modal by tapping Done (រួចរាល់)
      await tester.tap(find.byKey(const Key('apply_inspection_scope_button')));
      await tester.pumpAndSettle();

      // Verify redundant status capsule labels are removed from main screen
      expect(find.text('12/13 ប្រភេទកំហុស'), findsNothing);

      // Re-open modal to verify custom notes and defect tag state persisted
      await tester.tap(find.byKey(const Key('open_inspection_scope_modal_button')));
      await tester.pumpAndSettle();
      expect(find.text('Front bumper parking scrape'), findsOneWidget);
      await tester.tap(find.byKey(const Key('apply_inspection_scope_button')));
      await tester.pumpAndSettle();

      // Toggle to English and verify clean English labels
      await tester.ensureVisible(find.text('ខ្មែរ'));
      await tester.tap(find.text('ខ្មែរ'));
      await tester.pumpAndSettle();

      expect(find.text('SV - Vehicle Fault Detection'), findsOneWidget);
      expect(find.text('Snap Photo'), findsOneWidget);
      expect(find.text('Import Photos'), findsOneWidget);
      expect(find.text('Inspection Target & Defect Focus'), findsOneWidget);
      expect(find.text('Full Vehicle'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Detect Vehicle Faults & Damage'), findsOneWidget);

      // Open modal in English
      await tester.tap(find.byKey(const Key('open_inspection_scope_modal_button')));
      await tester.pumpAndSettle();

      expect(find.text('Engine & Machine Bay'), findsOneWidget);
      expect(find.text('Engine / Machine Fault'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Dents & Creases'), findsOneWidget);
      expect(find.text('Deep Scratches'), findsOneWidget);

      await tester.tap(find.byKey(const Key('apply_inspection_scope_button')));
      await tester.pumpAndSettle();
    });
  });

  group('ReportScreen & HistoryScreen widget tests', () {
    final sampleReport = DamageReport(
      id: 'rep-1',
      createdAt: DateTime(2026, 10, 20, 10, 30),
      sourceMediaPath: '',
      providerLabel: 'Google Gemini',
      modelUsed: 'gemini-2.0-flash',
      overallConfidence: 0.88,
      summary: 'Moderate dent on front bumper and minor scratch on left door.',
      summaryKhmer: 'មានស្នាមកំពិតនៅកាងមុខ និងស្នាមឆ្កូតតិចតួចនៅទ្វារឆ្វេង។',
      items: const [
        DamageItem(
          partName: 'Exposed Front Supports',
          partNameKhmer: 'គ្រោងទ្រខាងមុខដែលលាតត្រដាង',
          damageType: 'rust',
          severity: DamageSeverity.moderate,
          confidence: 0.97,
          notes:
              'Visible corrosion and flaking paint on lower brackets and upright supports; no definite rust-through established.',
        ),
        DamageItem(
          partName: 'Windshield',
          partNameKhmer: 'កញ្ចក់មុខ',
          damageType: 'crack',
          severity: DamageSeverity.minor,
          confidence: 0.84,
          notes:
              'Long, branching crack-like lines are visible across the upper windshield and toward the right side; reflections limit certainty.',
          notesKhmer:
              'ឃើញមានស្នាមប្រេះបែកជាខ្សែវែងនៅលើកញ្ចក់មុខផ្នែកខាងលើ និងឆ្ពោះទៅផ្នែកខាងស្តាំ។',
        ),
      ],
    );

    testWidgets(
        'ReportScreen renders clean Khmer severity, defect types (Rust/Crack), Khmer descriptions, and Listen Khmer/English buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final spokenLog = <Map<String, String>>[];
      final fakeTtsController = TtsController(
        customSpeakHandler: (id, text, langCode) async {
          spokenLog.add({'id': id, 'text': text, 'langCode': langCode});
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsControllerProvider.overrideWith((ref) => fakeTtsController),
          ],
          child: MaterialApp(
            home: ReportScreen(report: sampleReport),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clean Khmer labels without duplicate English lines
      expect(find.text('របាយការណ៍វិភាគការខូចខាត'), findsOneWidget);
      expect(find.text('ភាពត្រឹមត្រូវ 88%'), findsOneWidget);
      expect(find.text('ភាពត្រឹមត្រូវ'), findsWidgets);
      expect(find.text('គ្រោងទ្រខាងមុខដែលលាតត្រដាង'), findsOneWidget);
      expect(find.text('កញ្ចក់មុខ'), findsOneWidget);
      expect(find.text('ច្រេះ និងពុកផុយ'), findsOneWidget);
      expect(find.text('ប្រេះបែក'), findsOneWidget);

      // Verify Khmer description is rendered for both legacy notes fallback and direct notesKhmer
      expect(find.textContaining('មានស្នាមច្រេះ និងការពុកផុយនៃលោហៈ'),
          findsOneWidget);
      expect(
          find.text(
              'ឃើញមានស្នាមប្រេះបែកជាខ្សែវែងនៅលើកញ្ចក់មុខផ្នែកខាងលើ និងឆ្ពោះទៅផ្នែកខាងស្តាំ។'),
          findsOneWidget);

      // Verify Listen Khmer (ស្ដាប់ខ្មែរ) and Listen English (Listen EN) buttons exist
      expect(find.byKey(const Key('listen_summary_km')), findsOneWidget);
      expect(find.byKey(const Key('listen_summary_en')), findsOneWidget);
      expect(find.byKey(const Key('listen_item_1_km')), findsOneWidget);
      expect(find.byKey(const Key('listen_item_1_en')), findsOneWidget);
      expect(find.byKey(const Key('listen_item_2_km')), findsOneWidget);
      expect(find.byKey(const Key('listen_item_2_en')), findsOneWidget);

      // By default, English labels & descriptions are hidden in Khmer mode
      expect(find.text('Exposed Front Supports'), findsNothing);
      expect(find.text('Windshield'), findsNothing);
      expect(find.byKey(const Key('toggle_en_summary')), findsOneWidget);
      expect(find.byKey(const Key('toggle_en_all_items')), findsOneWidget);
      expect(find.byKey(const Key('toggle_en_item_1')), findsOneWidget);
      expect(find.byKey(const Key('toggle_en_item_2')), findsOneWidget);

      // Toggle EN on Item #1 -> shows English part name, severity/type, and description
      await tester.tap(find.byKey(const Key('toggle_en_item_1')));
      await tester.pumpAndSettle();
      expect(find.text('Exposed Front Supports'), findsOneWidget);
      expect(
          find.textContaining('Visible corrosion and flaking paint on lower brackets'),
          findsOneWidget);
      expect(find.text('Windshield'), findsNothing);

      // Toggle EN off on Item #1 -> hides English labels again
      await tester.tap(find.byKey(const Key('toggle_en_item_1')));
      await tester.pumpAndSettle();
      expect(find.text('Exposed Front Supports'), findsNothing);

      // Toggle EN for all items at once
      await tester.tap(find.byKey(const Key('toggle_en_all_items')));
      await tester.pumpAndSettle();
      expect(find.text('Exposed Front Supports'), findsOneWidget);
      expect(find.text('Windshield'), findsOneWidget);

      // Collapse all items EN toggle
      await tester.tap(find.byKey(const Key('toggle_en_all_items')));
      await tester.pumpAndSettle();
      expect(find.text('Exposed Front Supports'), findsNothing);
      expect(find.text('Windshield'), findsNothing);

      // Tap Listen Khmer on Item #1
      await tester.tap(find.byKey(const Key('listen_item_1_km')));
      await tester.pump();

      expect(spokenLog.length, equals(1));
      expect(spokenLog.first['id'], equals('item_1_km'));
      expect(spokenLog.first['langCode'], equals('km'));
      expect(spokenLog.first['text'], contains('គ្រោងទ្រខាងមុខដែលលាតត្រដាង'));
      expect(spokenLog.first['text'], contains('មធ្យម'));
      expect(spokenLog.first['text'], contains('ច្រេះ និងពុកផុយ'));

      // Tap Listen English on Item #1 (also auto-shows EN labels for item #1)
      await tester.tap(find.byKey(const Key('listen_item_1_en')));
      await tester.pump();

      expect(spokenLog.length, equals(2));
      expect(spokenLog.last['id'], equals('item_1_en'));
      expect(spokenLog.last['langCode'], equals('en'));
      expect(spokenLog.last['text'], contains('Exposed Front Supports'));
      expect(spokenLog.last['text'], contains('Moderate'));
      expect(find.text('Exposed Front Supports'), findsOneWidget);

      // Tap the 'ស្រាល' (Minor) metric card to filter
      await tester.tap(find.text('ស្រាល').first);
      await tester.pumpAndSettle();

      expect(find.text('កញ្ចក់មុខ'), findsOneWidget);
      expect(find.text('គ្រោងទ្រខាងមុខដែលលាតត្រដាង'), findsNothing);
    });

    test('All Khmer localization strings contain zero Thai characters', () {
      const kmStrings = AppStrings(AppLanguage.km);
      final samples = <String>[
        kmStrings.appTitle,
        kmStrings.importGalleryShort,
        kmStrings.contextNotesSubtitle,
        kmStrings.guidanceFooter,
        kmStrings.diagnosticReportTitle,
        kmStrings.listenKhmerBtn,
        kmStrings.stopListeningBtn,
        KhmerAutomotiveTranslator.severityKhmer(DamageSeverity.severe),
        KhmerAutomotiveTranslator.severityKhmer(DamageSeverity.moderate),
        KhmerAutomotiveTranslator.severityKhmer(DamageSeverity.minor),
        KhmerAutomotiveTranslator.damageTypeKhmer('rust'),
        KhmerAutomotiveTranslator.damageTypeKhmer('crack'),
        KhmerAutomotiveTranslator.damageTypeKhmer('dent'),
        KhmerAutomotiveTranslator.partNameKhmer('Windshield'),
        KhmerAutomotiveTranslator.partNameKhmer(
            'Front Grille / Lower Support Bracket'),
      ];

      for (final s in samples) {
        expect(
          KhmerAutomotiveTranslator.containsThaiScript(s),
          isFalse,
          reason: 'String "$s" must not contain any Thai characters',
        );
      }
    });

    testWidgets('HistoryScreen renders KPI banner and filters reports',
        (tester) async {
      final fakeHistory = FakeHistoryService([sampleReport]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyServiceProvider.overrideWithValue(fakeHistory),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ប្រវត្តិការត្រួតពិនិត្យ'), findsOneWidget);
      expect(find.text('រកឃើញកំហុស 2 ចំណុច'), findsOneWidget);
      expect(find.text('88%'), findsWidgets);
    });
  });

  group('Video keyframe extraction & URL media import tests', () {
    test('MediaUtils.detectMediaKind & normalizeMediaUrl classify images and videos accurately', () {
      // JPEG magic bytes
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01
      ]);
      expect(
        MediaUtils.detectMediaKind(bytes: jpegBytes),
        equals(DownloadedMediaKind.image),
      );

      // MP4 magic bytes (....ftypisom)
      final mp4Bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D
      ]);
      expect(
        MediaUtils.detectMediaKind(bytes: mp4Bytes),
        equals(DownloadedMediaKind.video),
      );

      // Google Drive & Dropbox URL normalization
      expect(
        MediaUtils.normalizeMediaUrl(
          'https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/view?usp=sharing',
        ),
        equals('https://drive.google.com/uc?export=download&id=1AbCdEfGhIjKlMnOp'),
      );
      expect(
        MediaUtils.normalizeMediaUrl(
          'https://www.dropbox.com/s/xyz/car.mp4?dl=0',
        ),
        equals('https://www.dropbox.com/s/xyz/car.mp4?dl=1'),
      );

      // YouTube Shorts / Watch / youtu.be video ID extraction
      expect(
        MediaUtils.extractYouTubeVideoId(
          'https://youtube.com/shorts/oy9TNv5dUx4?si=YP7PSk9dMoufjktz',
        ),
        equals('oy9TNv5dUx4'),
      );
      expect(
        MediaUtils.extractYouTubeVideoId(
          'https://www.youtube.com/watch?v=oy9TNv5dUx4&t=5s',
        ),
        equals('oy9TNv5dUx4'),
      );
      expect(
        MediaUtils.extractYouTubeVideoId('https://youtu.be/oy9TNv5dUx4'),
        equals('oy9TNv5dUx4'),
      );

      // OpenGraph HTML embedded media extraction
      const sampleHtml = '''
        <html><head>
          <meta property="og:video" content="https://cdn.example.com/vehicle_clip.mp4" />
        </head></html>
      ''';
      expect(
        MediaUtils.extractEmbeddedMediaUrlFromHtml(
          sampleHtml,
          Uri.parse('https://example.com/post/123'),
        ),
        equals('https://cdn.example.com/vehicle_clip.mp4'),
      );
    });

    testWidgets(
        'CaptureScreen imports both Image URL and Video URL (with keyframe extraction)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        MediaUtils.customUrlDownloader = null;
        MediaUtils.customFrameExtractor = null;
      });

      late final File fakeImgFile;
      late final File fakeVideoFile;
      late final File fakeFrame1;
      late final File fakeFrame2;

      await tester.runAsync(() async {
        final tempDir = await Directory.systemTemp.createTemp('vda_url_test_');
        final sampleImg = img.Image(width: 120, height: 90);
        img.fill(sampleImg, color: img.ColorRgb8(30, 90, 200));
        final jpgBytes = img.encodeJpg(sampleImg);

        fakeImgFile = File('${tempDir.path}/url_car.jpg');
        await fakeImgFile.writeAsBytes(jpgBytes);
        fakeVideoFile = File('${tempDir.path}/url_walkaround.mp4');
        await fakeVideoFile.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112]);
        fakeFrame1 = File('${tempDir.path}/frame_1.jpg');
        fakeFrame2 = File('${tempDir.path}/frame_2.jpg');
        await fakeFrame1.writeAsBytes(jpgBytes);
        await fakeFrame2.writeAsBytes(jpgBytes);
      });

      MediaUtils.customUrlDownloader = (url) async {
        if (url.endsWith('.mp4')) {
          return DownloadedMediaResult(
            file: fakeVideoFile,
            kind: DownloadedMediaKind.video,
            sourceUrl: url,
          );
        }
        return DownloadedMediaResult(
          file: fakeImgFile,
          kind: DownloadedMediaKind.image,
          sourceUrl: url,
        );
      };
      MediaUtils.customFrameExtractor = (videoPath, frameCount) async {
        return [fakeFrame1, fakeFrame2];
      };

      final fakeConfigService = FakeConfigService(
        const AIProviderConfig(
          kind: AIProviderKind.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          apiKey: 'AIzaSyFakeKey',
          model: 'gemini-2.0-flash',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configServiceProvider.overrideWithValue(fakeConfigService),
          ],
          child: const MaterialApp(
            home: CaptureScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Tap 'បញ្ចូលពីតំណ URL' (Import from URL) button
      expect(find.byKey(const Key('import_url_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('import_url_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('បញ្ចូលរូបភាព ឬវីដេអូតាមតំណ URL'),
        findsOneWidget,
      );

      // Enter an image URL and submit
      await tester.enterText(
        find.byKey(const Key('url_input_field')),
        'https://example.com/bumper-dent.jpg',
      );
      await tester.tap(find.byKey(const Key('url_submit_button')));
      await tester.pumpAndSettle();

      // 1 photo is now staged
      expect(find.text('រូបភាពបានជ្រើសរើស (1)'), findsOneWidget);

      // 2. Tap 'តំណ URL' (From URL short button) to import a video URL
      await tester.tap(find.byKey(const Key('import_url_short_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('url_input_field')),
        'https://example.com/car-walkaround.mp4',
      );
      await tester.tap(find.byKey(const Key('url_submit_button')));
      await tester.pumpAndSettle();

      // Video keyframes (2 frames) were extracted and added -> total 3 staged photos!
      expect(find.text('រូបភាពបានជ្រើសរើស (3)'), findsOneWidget);
    });
  });
}
