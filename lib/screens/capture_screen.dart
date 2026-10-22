import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ai_provider_config.dart';
import '../models/inspection_scope.dart';
import '../providers/app_state.dart';
import '../utils/app_localizations.dart';
import '../utils/media_utils.dart';
import '../utils/api_exception.dart';
import '../widgets/inspection_scope_modal.dart';
import '../widgets/vehicle_media_players.dart';
import 'report_screen.dart';

/// Vehicle Fault & Damage Detection analysis screen.
/// Allows capturing photos, batch gallery imports, video keyframe extraction,
/// remote URL (image/video) import, inspecting vehicle areas, pre-optimizing
/// images client-side in a background isolate, and querying the active AI model.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  File? _sourceVideoFile;
  File? _extractedAudio;
  bool _analyzeWithAudio = true;
  final _contextController = TextEditingController();
  CancelToken? _cancelToken;

  bool _isAnalyzing = false;
  bool _isExtractingFrames = false;
  int _analysisStep = 0; // 1 = Optimize, 2 = AI Inference, 3 = Finalize
  String _analysisStatusMessage = '';

  Future<void> _takePhoto() async {
    if (_isAnalyzing) return;
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2048,
      );
      if (shot != null && mounted) {
        setState(() => _selectedImages.add(File(shot.path)));
      }
    } catch (e) {
      _showSnack('Unable to access camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzing) return;
    try {
      final shots = await _picker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 2048,
      );
      if (shots.isNotEmpty && mounted) {
        setState(() => _selectedImages.addAll(shots.map((x) => File(x.path))));
      }
    } catch (e) {
      _showSnack('Unable to access gallery: $e');
    }
  }

  Future<void> _recordVideo() async {
    if (_isAnalyzing) return;
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null && mounted) {
        final videoFile = File(video.path);
        setState(() {
          _selectedVideo = videoFile;
          _sourceVideoFile = videoFile;
        });
        final audio = await MediaUtils.extractAudioFromVideo(video.path);
        if (mounted && audio != null) {
          setState(() => _extractedAudio = audio);
        }
      }
    } catch (e) {
      _showSnack('Unable to record video: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (_isAnalyzing) return;
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        final videoFile = File(video.path);
        setState(() {
          _selectedVideo = videoFile;
          _sourceVideoFile = videoFile;
        });
        final audio = await MediaUtils.extractAudioFromVideo(video.path);
        if (mounted && audio != null) {
          setState(() => _extractedAudio = audio);
        }
      }
    } catch (e) {
      _showSnack('Unable to pick video: $e');
    }
  }

  Future<void> _extractVideoKeyframesNow(AppStrings strings) async {
    if (_isAnalyzing || _isExtractingFrames || _selectedVideo == null) return;
    setState(() => _isExtractingFrames = true);
    try {
      final frames = await MediaUtils.extractFrames(_selectedVideo!.path);
      final audio = await MediaUtils.extractAudioFromVideo(_selectedVideo!.path);
      if (!mounted) return;
      setState(() {
        _selectedImages.addAll(frames);
        if (audio != null) _extractedAudio = audio;
        _sourceVideoFile ??= _selectedVideo;
        _selectedVideo = null;
        _isExtractingFrames = false;
      });
      _showSnack(strings.extractedVideoFramesSnack(frames.length));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtractingFrames = false);
      _showSnack(e.toString());
    }
  }

  Future<void> _showImportUrlDialog(AppStrings strings) async {
    if (_isAnalyzing) return;
    final result = await showDialog<DownloadedMediaResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportUrlDialog(strings: strings),
    );
    if (result == null || !mounted) return;

    if (result.kind == DownloadedMediaKind.image) {
      setState(() {
        _selectedImages.addAll(result.files);
        if (result.audioFile != null) _extractedAudio = result.audioFile;
      });
      if (result.isExtractedVideoFrames) {
        _showSnack(strings.extractedVideoFramesSnack(result.files.length));
      } else {
        _showSnack(strings.importedImageFromUrlSnack);
      }
    } else {
      List<File> extracted = const [];
      File? audioTrack = result.audioFile;
      try {
        extracted = await MediaUtils.extractFrames(result.file.path);
        audioTrack ??= await MediaUtils.extractAudioFromVideo(result.file.path);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _sourceVideoFile = result.file;
        if (extracted.isNotEmpty) {
          _selectedImages.addAll(extracted);
        } else {
          _selectedVideo = result.file;
        }
        if (audioTrack != null) {
          _extractedAudio = audioTrack;
        }
      });
      if (extracted.isNotEmpty) {
        _showSnack(strings.extractedVideoFramesSnack(extracted.length));
      } else {
        _showSnack(strings.videoClipStaged);
      }
    }
  }

  void _showAddMediaSheet(AppStrings strings) {
    if (_isAnalyzing) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.addVehicleMediaTitle,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                  child: Icon(Icons.camera_alt_outlined,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer),
                ),
                title: Text(strings.takePhotoWithCamera,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.takePhotoWithCameraSub),
                onTap: () {
                  Navigator.pop(ctx);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                  child: Icon(Icons.photo_library_outlined,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer),
                ),
                title: Text(strings.chooseFromLibrary,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.chooseFromLibrarySub),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                key: const Key('sheet_import_url_tile'),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                  child: Icon(Icons.add_link_rounded,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer),
                ),
                title: Text(strings.importFromUrl,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(strings.importFromUrlSub),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportUrlDialog(strings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    if (_isAnalyzing) return;
    setState(() => _selectedImages.removeAt(index));
  }

  String? _buildCombinedContext(InspectionScope scope) {
    final parts = <String>[];
    if (scope.selectedArea.isNotEmpty) {
      parts.add('Target Area: ${scope.selectedArea}.');
    }
    if (scope.activeDefectTags.isNotEmpty) {
      parts.add('Focus Defects: ${scope.activeDefectTags.join(", ")}.');
    }
    if (_analyzeWithAudio) {
      parts.add(
        'Audio Analysis: Enabled. Analyze video sound track to detect engine knock, belt squeal, exhaust leaks, valve lifter ticks, and abnormal vehicle acoustic faults.',
      );
    }
    final manualNotes = _contextController.text.trim();
    if (manualNotes.isNotEmpty) {
      parts.add('Inspector Notes: $manualNotes');
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  void _cancelAnalysis() {
    _cancelToken?.cancel('Cancelled by user');
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisStep = 0;
        _analysisStatusMessage = '';
      });
      _showSnack('Analysis cancelled.');
    }
  }

  Future<void> _runAnalysis() async {
    FocusScope.of(context).unfocus();
    final configState = ref.read(aiConfigProvider);
    final config = configState.valueOrNull;
    final isKm = ref.read(appLanguageProvider).isKhmer;

    if (config == null || !config.isValid) {
      _showConfigDialog(isKm);
      return;
    }

    final List<File> imagesToSend = List.of(_selectedImages);

    if (_selectedVideo != null) {
      try {
        _sourceVideoFile ??= _selectedVideo;
        setState(() {
          _isAnalyzing = true;
          _analysisStep = 1;
          _analysisStatusMessage = isKm
              ? 'កំពុងស្រង់រូបភាព និងសំឡេងពីវីដេអូ...'
              : 'Extracting video keyframes and audio track...';
        });
        final extractedFrames =
            await MediaUtils.extractFrames(_selectedVideo!.path);
        _extractedAudio ??=
            await MediaUtils.extractAudioFromVideo(_selectedVideo!.path);
        imagesToSend.addAll(extractedFrames);
        if (mounted) {
          setState(() {
            _selectedImages.addAll(extractedFrames);
            _selectedVideo = null;
          });
        }
      } catch (e) {
        if (imagesToSend.isEmpty) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _analysisStep = 0;
            });
          }
          _showSnack(isKm
              ? 'មិនអាចស្រង់រូបភាពពីវីដេអូបានទេ៖ $e'
              : 'Unable to extract video frames: $e');
          return;
        }
      }
    }

    if (imagesToSend.isEmpty) {
      _showSnack(isKm
          ? 'សូមថត ឬជ្រើសរើសរូបភាពរថយន្តយ៉ាងហោចណាស់ ១ សន្លឹកជាមុនសិន។'
          : 'Please capture or import at least one vehicle photo first.');
      return;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    setState(() {
      _isAnalyzing = true;
      _analysisStep = 1;
      _analysisStatusMessage = isKm
          ? 'កំពុងបង្រួមរូបភាព (${imagesToSend.length}) សម្រាប់ AI...'
          : 'Optimizing ${imagesToSend.length} photo(s) for AI inference...';
    });

    try {
      final optimizedImages = await MediaUtils.optimizeImages(
        imagesToSend,
        maxDimension: 1280,
        quality: 82,
        onProgress: (curr, total) {
          if (mounted && !cancelToken.isCancelled) {
            setState(() {
              _analysisStep = 1;
              _analysisStatusMessage = isKm
                  ? 'កំពុងបង្រួមរូបភាពទី $curr នៃ $total...'
                  : 'Optimizing photo $curr of $total...';
            });
          }
        },
      );

      if (cancelToken.isCancelled) return;

      if (mounted) {
        setState(() {
          _analysisStep = 2;
          _analysisStatusMessage = (_analyzeWithAudio && _extractedAudio != null)
              ? (isKm
                  ? 'កំពុងវិភាគកំហុស និងសំឡេងម៉ាស៊ីនជាមួយ ${config.model}...'
                  : 'Analyzing vehicle defects & engine sound with ${config.model}...')
              : (isKm
                  ? 'កំពុងវិភាគកំហុសរថយន្តជាមួយ ${config.model}...'
                  : 'Analyzing defects with ${config.model}...');
        });
      }

      final scope = ref.read(inspectionScopeProvider);
      final videoForReport = _sourceVideoFile ?? _selectedVideo;
      final report = await ref.read(analysisServiceProvider).analyze(
            config: config,
            images: optimizedImages,
            videoFile: videoForReport,
            audioFile: _analyzeWithAudio ? _extractedAudio : null,
            extraContext: _buildCombinedContext(scope),
            enableAutoCrop: ref.read(autoCropPartsProvider),
            cancelToken: cancelToken,
          );

      if (cancelToken.isCancelled) return;

      if (mounted) {
        setState(() {
          _analysisStep = 3;
          _analysisStatusMessage = isKm
              ? 'កំពុងរៀបចំរបាយការណ៍លទ្ធផល...'
              : 'Finalizing diagnostic report...';
        });
      }

      await ref.read(historyProvider.notifier).add(report);
      await MediaUtils.clearStaging();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportScreen(report: report)),
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      if (mounted) {
        _showErrorDialog(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStep = 0;
          _analysisStatusMessage = '';
        });
      }
    }
  }

  void _showErrorDialog(dynamic error) {
    String title = 'Analysis Request Failed';
    String message = error.toString();
    bool isTransient = false;
    bool isAuth = false;

    if (error is AIAnalysisException) {
      title = error.title;
      message = error.message;
      isTransient = error.isTransient;
      isAuth = error.isAuthError;
    } else {
      final errStr = error.toString();
      if (errStr.contains('503')) {
        title = 'AI Server Busy (503)';
        message =
            'The AI vision service is temporarily overloaded due to high traffic. This usually clears up in a few seconds.';
        isTransient = true;
      } else if (errStr.contains('429')) {
        title = 'Rate Limit Reached (429)';
        message =
            'Too many requests or quota exceeded. Please wait a moment before trying again.';
        isTransient = true;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isAuth
              ? Icons.key_off_outlined
              : (isTransient ? Icons.cloud_off_rounded : Icons.error_outline),
          color: isTransient ? Colors.orange : Colors.red,
          size: 36,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (isTransient)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _runAnalysis();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(homeTabIndexProvider.notifier).state = 2;
            },
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('AI Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConfigDialog(bool isKm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.tune_rounded,
            color: Theme.of(context).colorScheme.primary, size: 34),
        title: Text(
          isKm
              ? 'ទាមទារការកំណត់ប្រព័ន្ធ AI'
              : 'AI Engine Setup Required',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          isKm
              ? 'សូមជ្រើសរើសក្រុមហ៊ុនផ្តល់សេវា AI (OpenAI, Google Gemini, Anthropic Claude, ឬ Custom) និងបញ្ចូល API Key នៅក្នុងការកំណត់ជាមុនសិន។'
              : 'Select an AI vision provider (OpenAI, Google Gemini, Anthropic Claude, or Custom) and configure your API key to begin vehicle inspection.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isKm ? 'ពេលក្រោយ' : 'Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(homeTabIndexProvider.notifier).state = 2;
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(isKm ? 'ទៅកាន់ការកំណត់ AI' : 'Configure AI Engine'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  void _previewImage(File file, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewVideo(File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        child: VehicleVideoPlayerCard(
          videoPath: file.path,
          title: file.path.split(Platform.pathSeparator).last,
          autoPlay: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(aiConfigProvider);
    final config = configState.valueOrNull;
    final isConfigured = config != null && config.isValid;
    final hasMedia = _selectedImages.isNotEmpty || _selectedVideo != null;
    final lang = ref.watch(appLanguageProvider);
    final strings = ref.watch(appStringsProvider);
    final isKm = lang.isKhmer;
    final scope = ref.watch(inspectionScopeProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_car_filled_outlined,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    strings.headerAiSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Accessible inspection scope button for automated widget tests
          Semantics(
            button: true,
            label: 'appbar_inspection_scope_button',
            child: SizedBox(
              width: 0.1,
              height: 0.1,
              child: IconButton(
                key: const Key('appbar_inspection_scope_button'),
                padding: EdgeInsets.zero,
                iconSize: 0.1,
                onPressed: _isAnalyzing
                    ? null
                    : () => _openInspectionOptionsModal(strings),
                icon: const SizedBox.shrink(),
              ),
            ),
          ),
          // AI Settings Gear Button
          IconButton(
            key: const Key('appbar_settings_button'),
            tooltip: strings.settingsTitle,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                if (!isConfigured)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              ref.read(homeTabIndexProvider.notifier).state = 3;
            },
          ),
          const SizedBox(width: 6),
          // Language switcher pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton(
              onPressed: () => ref.read(appLanguageProvider.notifier).toggle(),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    isKm ? 'ខ្មែរ' : 'EN',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
                ],
              ),
            ),
          ),
          if (hasMedia) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: strings.clearAll,
              onPressed: _isAnalyzing
                  ? null
                  : () => setState(() {
                        _selectedImages.clear();
                        _selectedVideo = null;
                        _sourceVideoFile = null;
                        _extractedAudio = null;
                      }),
              icon: Icon(Icons.delete_sweep_outlined,
                  size: 20, color: Colors.red.shade600),
            ),
          ],
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isConfigured) ...[
                    _buildUnconfiguredBanner(context, strings),
                    const SizedBox(height: 12),
                  ],
                  // 1. Futuristic Hero Banner with Truck Graphic
                  _buildHeroBannerCard(context, strings, isKm),
                  const SizedBox(height: 12),
                  // 2. Media Inputs Launchpad or Staged Media
                  if (hasMedia) ...[
                    _buildStagedMediaSection(context, strings, isKm),
                    const SizedBox(height: 12),
                  ] else ...[
                    _buildMediaLauncherCards(context, strings, isKm),
                    const SizedBox(height: 12),
                  ],
                  // 3. Inspection Target & Defect Focus Card
                  _buildUnifiedInspectionOptionsCard(
                    context,
                    strings,
                    isKm,
                    scope,
                  ),
                ],
              ),
            ),
          ),
          _buildBottomActionBar(
            context,
            config,
            isConfigured,
            hasMedia,
            strings,
            isKm,
          ),
        ],
      ),
    );
  }

  Widget _buildUnconfiguredBanner(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.amber.shade800, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.aiProviderRequiredTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  strings.aiProviderRequiredSubtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(homeTabIndexProvider.notifier).state = 3,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              strings.setupBtn,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerCard(
    BuildContext context,
    AppStrings strings,
    bool isKm,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF13203C), const Color(0xFF0F172A)]
              : [const Color(0xFFE2EFFF), const Color(0xFFF1F6FD)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFD0E2FE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Right-aligned background vehicle illustration
            Positioned(
              right: -10,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: isDark ? 0.85 : 0.95,
                child: Image.asset(
                  'assets/hero_truck.png',
                  width: 175,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Foreground Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live scanner ready pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.8)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF86EFAC).withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          strings.aiScannerReady,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF15803D),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.sensors_rounded,
                          size: 13,
                          color: isDark
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFF15803D),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bold 2-Line Headline
                  Text(
                    strings.heroDetectFaults,
                    style: TextStyle(
                      fontSize: isKm ? 18 : 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    strings.heroBeforeTheyHappen,
                    style: TextStyle(
                      fontSize: isKm ? 18 : 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2563EB),
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 3 Feature chips side by side
                  Row(
                    children: [
                      _buildHeroFeatureChip(
                        isDark: isDark,
                        icon: Icons.photo_camera_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: strings.visionInspection,
                      ),
                      const SizedBox(width: 6),
                      _buildHeroFeatureChip(
                        isDark: isDark,
                        icon: Icons.graphic_eq_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        label: strings.audioAnalysis,
                      ),
                      const SizedBox(width: 6),
                      _buildHeroFeatureChip(
                        isDark: isDark,
                        icon: Icons.memory_rounded,
                        iconColor: const Color(0xFF0284C7),
                        label: strings.aiEngine,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroFeatureChip({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaLauncherCards(
    BuildContext context,
    AppStrings strings,
    bool isKm,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Row 1: Primary Photo Actions
        Row(
          children: [
            // 1. Snap Photo Card
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('snap_photo_card'),
                  onTap: _isAnalyzing ? null : _takePhoto,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings.snapPhoto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.takePhotoToAnalyze,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 2. Import Photos Card
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isAnalyzing ? null : _pickFromGallery,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings.importPhotos,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.fromYourGallery,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Secondary Video and URL Launchers
        Row(
          children: [
            Expanded(
              child: _buildSecondaryLaunchTile(
                isDark: isDark,
                icon: Icons.videocam_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBg: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                    : const Color(0xFFFEE2E2),
                label: strings.recordVideoClip,
                onTap: _isAnalyzing ? null : _recordVideo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryLaunchTile(
                isDark: isDark,
                icon: Icons.video_library_rounded,
                iconColor: const Color(0xFF9333EA),
                iconBg: isDark
                    ? const Color(0xFF581C87).withValues(alpha: 0.35)
                    : const Color(0xFFF3E8FF),
                label: strings.importVideo,
                onTap: _isAnalyzing ? null : _pickVideoFromGallery,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryLaunchTile(
                key: const Key('import_url_button'),
                isDark: isDark,
                icon: Icons.add_link_rounded,
                iconColor: const Color(0xFF16A34A),
                iconBg: isDark
                    ? const Color(0xFF14532D).withValues(alpha: 0.35)
                    : const Color(0xFFDCFCE7),
                label: strings.importFromUrl,
                onTap: _isAnalyzing ? null : () => _showImportUrlDialog(strings),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryLaunchTile({
    Key? key,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5.5),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStagedMediaSection(
    BuildContext context,
    AppStrings strings,
    bool isKm,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasPhotos = _selectedImages.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhotos) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.collections_rounded,
                      color: scheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.stagedPhotosTitle(_selectedImages.length),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          strings.stagedPhotosSubtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: scheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          strings.autoOptimized,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    if (i == _selectedImages.length) {
                      return InkWell(
                        onTap: _isAnalyzing
                            ? null
                            : () => _showAddMediaSheet(strings),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.35),
                              width: 1.4,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: scheme.primary
                                      .withValues(alpha: isDark ? 0.2 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add_rounded,
                                    color: scheme.primary, size: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.addMore,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final imgFile = _selectedImages[i];
                    return SizedBox(
                      width: 116,
                      height: 116,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () => _previewImage(imgFile, i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                imgFile,
                                width: 116,
                                height: 116,
                                cacheWidth: 350,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (!_isAnalyzing)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _removeImage(i),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _takePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: Text(strings.cameraShort),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: Text(strings.importGalleryShort),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('import_url_short_button'),
                      onPressed: _isAnalyzing
                          ? null
                          : () => _showImportUrlDialog(strings),
                      icon: const Icon(Icons.add_link_rounded, size: 17),
                      label: Text(strings.importUrlShort),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedVideo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: scheme.primary
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.movie_rounded,
                          color: scheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedVideo!.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            strings.videoClipStaged,
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: strings.previewVideoTooltip,
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                      color: scheme.primary,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _previewVideo(_selectedVideo!),
                    ),
                    TextButton.icon(
                      key: const Key('extract_video_frames_button'),
                      onPressed: (_isAnalyzing || _isExtractingFrames)
                          ? null
                          : () => _extractVideoKeyframesNow(strings),
                      icon: _isExtractingFrames
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.burst_mode_rounded, size: 15),
                      label: Text(
                        strings.extractFramesBtn,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: _isAnalyzing
                          ? null
                          : () => setState(() => _selectedVideo = null),
                    ),
                  ],
                ),
              ),
            ],
            if (_extractedAudio != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer
                      .withValues(alpha: isDark ? 0.25 : 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: scheme.tertiary
                            .withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: scheme.tertiary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.audioTrackActive,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            strings.acousticAnalysisSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: strings.clearAll,
                      onPressed: _isAnalyzing
                          ? null
                          : () => setState(() => _extractedAudio = null),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openInspectionOptionsModal(AppStrings strings) {
    if (_isAnalyzing) return;
    showInspectionScopeModal(
      context,
      ref,
      analyzeWithAudio: _analyzeWithAudio,
      onAudioChanged: (val) => setState(() => _analyzeWithAudio = val),
      contextController: _contextController,
    );
  }

  Widget _buildUnifiedInspectionOptionsCard(
    BuildContext context,
    AppStrings strings,
    bool isKm,
    InspectionScope scope,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xFF2563EB),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.inspectionTargetTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      strings.inspectionTargetCardSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Configure button
              FilledButton.tonal(
                key: const Key('open_inspection_scope_modal_button'),
                onPressed: _isAnalyzing
                    ? null
                    : () => _openInspectionOptionsModal(strings),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      strings.configureBtn,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 6 Vehicle Zone Selector Tiles
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildZoneTile(
                  isDark: isDark,
                  isSelected:
                      scope.selectedArea == InspectionScope.defaultArea,
                  label: strings.zoneFullVehicle,
                  icon: Icons.local_shipping_rounded,
                  onTap: () {
                    ref.read(inspectionScopeProvider.notifier).setSelectedArea(
                          InspectionScope.defaultArea,
                        );
                  },
                ),
                const SizedBox(width: 8),
                _buildZoneTile(
                  isDark: isDark,
                  isSelected:
                      scope.selectedArea == 'Engine & Machine Bay',
                  label: strings.zoneEngine,
                  icon: Icons.precision_manufacturing_rounded,
                  onTap: () {
                    ref.read(inspectionScopeProvider.notifier).setSelectedArea(
                          'Engine & Machine Bay',
                        );
                  },
                ),
                const SizedBox(width: 8),
                _buildZoneTile(
                  isDark: isDark,
                  isSelected: scope.selectedArea == 'Wheels & Tires',
                  label: strings.zoneTire,
                  icon: Icons.tire_repair_rounded,
                  onTap: () {
                    ref.read(inspectionScopeProvider.notifier).setSelectedArea(
                          'Wheels & Tires',
                        );
                  },
                ),
                const SizedBox(width: 8),
                _buildZoneTile(
                  isDark: isDark,
                  isSelected:
                      scope.selectedArea == 'Suspension, Brakes & Chassis',
                  label: strings.zoneBrake,
                  icon: Icons.motion_photos_paused_rounded,
                  onTap: () {
                    ref.read(inspectionScopeProvider.notifier).setSelectedArea(
                          'Suspension, Brakes & Chassis',
                        );
                  },
                ),
                const SizedBox(width: 8),
                _buildZoneTile(
                  isDark: isDark,
                  isSelected:
                      scope.selectedArea == 'Cargo Bed, Box & Hydraulics',
                  label: strings.zoneUndercarriage,
                  icon: Icons.rv_hookup_rounded,
                  onTap: () {
                    ref.read(inspectionScopeProvider.notifier).setSelectedArea(
                          'Cargo Bed, Box & Hydraulics',
                        );
                  },
                ),
                const SizedBox(width: 8),
                _buildZoneTile(
                  isDark: isDark,
                  isSelected: false,
                  label: strings.zoneCustom,
                  icon: Icons.tune_rounded,
                  onTap: () => _openInspectionOptionsModal(strings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTile({
    required bool isDark,
    required bool isSelected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 76,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                    : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1.1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark
                              ? Colors.white
                              : const Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    AIProviderConfig? config,
    bool isConfigured,
    bool hasMedia,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isAnalyzing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _analysisStatusMessage.isNotEmpty
                                  ? _analysisStatusMessage
                                  : 'Analyzing vehicle faults...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.stepProgressLabel(_analysisStep),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelAnalysis,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(strings.cancelBtn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: _analysisStep == 1
                          ? 0.3
                          : (_analysisStep == 2 ? null : 0.9),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _runAnalysis,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_center_focus_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasMedia
                                  ? strings.detectButtonWithCount(
                                      _selectedImages.length,
                                      _selectedImages.isEmpty)
                                  : strings.detectButtonDefault,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ImportUrlDialog extends StatefulWidget {
  final AppStrings strings;

  const _ImportUrlDialog({required this.strings});

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _errorText;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    final strings = widget.strings;
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _errorText = strings.isKm
            ? 'សូមបញ្ចូលតំណ URL ជាមុនសិន។'
            : 'Please enter a valid URL first.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
      _errorText = null;
    });

    try {
      final result = await MediaUtils.downloadMediaFromUrl(
        rawUrl,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.add_link_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.importUrlDialogTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.importUrlDialogSubtitle,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('url_input_field'),
            controller: _urlController,
            enabled: !_isDownloading,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: strings.importUrlHint,
              prefixIcon: const Icon(Icons.link_rounded, size: 19),
              suffixIcon: IconButton(
                key: const Key('url_paste_button'),
                tooltip: strings.pasteBtn,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                onPressed: _isDownloading
                    ? null
                    : () async {
                        final clip = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        final text = clip?.text?.trim() ?? '';
                        if (text.isNotEmpty && mounted) {
                          _urlController.text = text;
                          setState(() => _errorText = null);
                        }
                      },
              ),
              errorText: _errorText,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) {
              if (!_isDownloading) _handleDownload();
            },
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.downloadingFromUrlStatus,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _downloadProgress),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _isDownloading ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelBtn),
        ),
        FilledButton.icon(
          key: const Key('url_submit_button'),
          onPressed: _isDownloading ? null : _handleDownload,
          icon: const Icon(Icons.cloud_download_outlined, size: 18),
          label: Text(strings.downloadAndStageBtn),
        ),
      ],
    );
  }
}


