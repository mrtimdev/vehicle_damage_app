import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Formats a [Duration] into `mm:ss`.
String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// An interactive, high-contrast, fully self-contained video player card for
/// viewing vehicle inspection videos recorded or downloaded from URLs.
class VehicleVideoPlayerCard extends StatefulWidget {
  final String videoPath;
  final String? title;
  final bool autoPlay;

  /// Test hook to bypass native platform video channel initialization in widget tests.
  static bool disableNativeDecoderForTesting = false;

  static bool get isTestEnvironment =>
      disableNativeDecoderForTesting ||
      Platform.environment.containsKey('FLUTTER_TEST');

  const VehicleVideoPlayerCard({
    super.key,
    required this.videoPath,
    this.title,
    this.autoPlay = false,
  });

  @override
  State<VehicleVideoPlayerCard> createState() => _VehicleVideoPlayerCardState();
}

class _VehicleVideoPlayerCardState extends State<VehicleVideoPlayerCard> {
  VideoPlayerController? _controller;
  late bool _isInitialized = false;
  late bool _hasError = VehicleVideoPlayerCard.isTestEnvironment;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VehicleVideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = VehicleVideoPlayerCard.isTestEnvironment;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (VehicleVideoPlayerCard.isTestEnvironment) {
      return;
    }

    final file = File(widget.videoPath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.setLooping(true);
      if (widget.autoPlay) {
        await controller.play();
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (_) {
      // In headless test environments or when native decoders are missing
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    _isMuted = !_isMuted;
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    setState(() {});
  }

  void _openFullScreenDialog() {
    if (_controller == null || !_isInitialized) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_controller!),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.redAccent,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = widget.videoPath.split(Platform.pathSeparator).last;

    if (_hasError || !_isInitialized) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: 180,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_file_outlined,
                  size: 44, color: scheme.primary.withValues(alpha: 0.8)),
              const SizedBox(height: 8),
              Text(
                widget.title ?? fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _hasError
                    ? 'Video Staged (${File(widget.videoPath).existsSync() ? "${(File(widget.videoPath).lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB" : "Pending"})'
                    : 'Loading video player...',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final aspectRatio = _controller!.value.aspectRatio > 0
        ? _controller!.value.aspectRatio.clamp(0.6, 2.4)
        : 16 / 9;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: scheme.surfaceContainerLow,
              child: Row(
                children: [
                  Icon(Icons.movie_filter_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Full Screen',
                    icon: const Icon(Icons.fullscreen, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: _openFullScreenDialog,
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
                if (!isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: scheme.surface,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  onPressed: _togglePlayPause,
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: scheme.primary,
                      bufferedColor: scheme.primary.withValues(alpha: 0.25),
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                  icon: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 20,
                  ),
                  onPressed: _toggleMute,
                ),
                IconButton(
                  tooltip: 'Fullscreen',
                  icon: const Icon(Icons.fullscreen_rounded, size: 22),
                  onPressed: _openFullScreenDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An interactive audio playback bar widget that allows users to play the
/// vehicle's extracted engine / mechanical sound track.
class VehicleAudioPlayerBar extends StatefulWidget {
  final String audioPath;
  final String? title;

  /// Test hook to bypass native platform audio channel initialization in widget tests.
  static bool disableNativeDecoderForTesting = false;

  static bool get isTestEnvironment =>
      disableNativeDecoderForTesting ||
      Platform.environment.containsKey('FLUTTER_TEST');

  const VehicleAudioPlayerBar({
    super.key,
    required this.audioPath,
    this.title,
  });

  @override
  State<VehicleAudioPlayerBar> createState() => _VehicleAudioPlayerBarState();
}

class _VehicleAudioPlayerBarState extends State<VehicleAudioPlayerBar> {
  VideoPlayerController? _controller;
  late bool _isInitialized = VehicleAudioPlayerBar.isTestEnvironment;
  late bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void didUpdateWidget(covariant VehicleAudioPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = VehicleAudioPlayerBar.isTestEnvironment;
      _hasError = false;
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    if (VehicleAudioPlayerBar.isTestEnvironment) {
      return;
    }

    final file = File(widget.audioPath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = _controller?.value.isPlaying ?? false;
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.audiotrack_rounded,
                size: 18,
                color: scheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title ?? 'Vehicle Audio Track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.tonalIcon(
                key: const Key('toggle_audio_playback_button'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: (_hasError || !_isInitialized)
                    ? null
                    : _togglePlayPause,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  isPlaying ? 'Pause' : 'Play Audio',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: (_controller != null && _isInitialized)
                    ? VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: scheme.tertiary,
                          bufferedColor: scheme.tertiary.withValues(alpha: 0.2),
                          backgroundColor: scheme.outlineVariant,
                        ),
                      )
                    : Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
