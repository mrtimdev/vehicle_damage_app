import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Most vision-capable AI APIs (OpenAI, Anthropic, Gemini) accept still
/// images, not raw video. For recorded clips, the app should extract a
/// handful of representative frames client-side (e.g. via a platform
/// video-thumbnail plugin or an ffmpeg binary) and send those frames the
/// same way as photos.
///
/// This file intentionally keeps frame extraction as a thin, swappable
/// layer: plug in `video_thumbnail`, `ffmpeg_kit_flutter`, or a native
/// implementation depending on your target platforms and licensing needs.
class MediaUtils {
  /// Returns a temp directory to stage extracted frames / compressed
  /// images before sending them to an AI provider.
  static Future<Directory> stagingDir() async {
    final dir = await getTemporaryDirectory();
    final staging = Directory(p.join(dir.path, 'vda_staging'));
    if (!await staging.exists()) {
      await staging.create(recursive: true);
    }
    return staging;
  }

  /// Placeholder frame-extraction hook. Wire this up to a real video
  /// frame extractor plugin of your choice. Returns the list of extracted
  /// still-image files ready to hand to [AnalysisService.analyze].
  ///
  /// Suggested implementation with `video_thumbnail`:
  /// ```dart
  /// final thumbPath = await VideoThumbnail.thumbnailFile(
  ///   video: videoPath,
  ///   thumbnailPath: (await stagingDir()).path,
  ///   imageFormat: ImageFormat.JPEG,
  ///   timeMs: timestampMs,
  ///   quality: 85,
  /// );
  /// ```
  static Future<List<File>> extractFrames(
    String videoPath, {
    int frameCount = 4,
  }) async {
    throw UnimplementedError(
      'Wire up a video-frame-extraction plugin (e.g. video_thumbnail or '
      'ffmpeg_kit_flutter) here. See method doc-comment for a starting '
      'point. Left unimplemented so you can choose licensing/binary size '
      'trade-offs for your target platforms.',
    );
  }

  /// Cleans up staged temp files after a successful upload/analysis.
  static Future<void> clearStaging() async {
    final dir = await stagingDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
