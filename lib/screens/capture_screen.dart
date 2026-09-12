import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_state.dart';
import '../utils/media_utils.dart';
import 'report_screen.dart';

/// Lets the user capture a photo, record a video, or upload existing
/// media from the gallery, then sends the selected images to the
/// configured AI provider for damage analysis.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  final _contextController = TextEditingController();
  bool _isAnalyzing = false;

  Future<void> _takePhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
    if (shot != null) {
      setState(() => _selectedImages.add(File(shot.path)));
    }
  }

  Future<void> _pickFromGallery() async {
    final shots = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
    if (shots.isNotEmpty) {
      setState(() => _selectedImages.addAll(shots.map((x) => File(x.path))));
    }
  }

  Future<void> _recordVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
    if (video != null) {
      setState(() => _selectedVideo = File(video.path));
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _selectedVideo = File(video.path));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _runAnalysis() async {
    final configState = ref.read(aiConfigProvider);
    final config = configState.value;

    if (config == null || !config.isValid) {
      _showSnack('Please configure an AI provider in Settings first.');
      return;
    }

    List<File> imagesToSend = List.of(_selectedImages);

    if (imagesToSend.isEmpty && _selectedVideo != null) {
      try {
        _showSnack('Extracting frames from video...');
        imagesToSend = await MediaUtils.extractFrames(_selectedVideo!.path);
      } catch (e) {
        _showSnack('Video frame extraction is not wired up yet. Please use photo capture or gallery upload for now.');
        return;
      }
    }

    if (imagesToSend.isEmpty) {
      _showSnack('Please capture or upload at least one photo.');
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final report = await ref.read(analysisServiceProvider).analyze(
            config: config,
            images: imagesToSend,
            extraContext: _contextController.text.trim().isEmpty ? null : _contextController.text.trim(),
          );
      await ref.read(historyProvider.notifier).add(report);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(report: report)));
      }
    } catch (e) {
      _showSnack('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Damage Analyzer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _accuracyNotice(context),
            const SizedBox(height: 16),
            Text('1. Capture or upload vehicle media', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Take Photo')),
                OutlinedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library), label: const Text('Upload Photos')),
                OutlinedButton.icon(onPressed: _recordVideo, icon: const Icon(Icons.videocam), label: const Text('Record Video')),
                OutlinedButton.icon(onPressed: _pickVideoFromGallery, icon: const Icon(Icons.video_library), label: const Text('Upload Video')),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedImages.isNotEmpty) ...[
              Text('Selected photos (${_selectedImages.length})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_selectedImages[i], width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedVideo != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie),
                  title: Text(_selectedVideo!.path.split('/').last),
                  subtitle: const Text('Video selected — frames will be extracted before analysis'),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedVideo = null)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('2. Add context (optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _contextController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. "Rear-end collision, focus on bumper and trunk"',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isAnalyzing ? null : _runAnalysis,
              icon: _isAnalyzing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Damage'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accuracyNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI analysis is assistive, not guaranteed. Each finding includes a confidence score — '
              'please manually verify low-confidence items before making decisions.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
