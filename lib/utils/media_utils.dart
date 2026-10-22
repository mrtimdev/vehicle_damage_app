import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoExtractionException implements Exception {
  final String message;
  VideoExtractionException([
    this.message =
        'Unable to extract keyframes from this video file. Please verify the video format (MP4/MOV) or upload photos directly.',
  ]);
  @override
  String toString() => message;
}

class UrlMediaDownloadException implements Exception {
  final String message;
  const UrlMediaDownloadException(this.message);
  @override
  String toString() => message;
}

enum DownloadedMediaKind { image, video }

class DownloadedMediaResult {
  final List<File> files;
  final DownloadedMediaKind kind;
  final String sourceUrl;
  final bool isExtractedVideoFrames;
  final File? audioFile;

  DownloadedMediaResult({
    File? file,
    List<File>? files,
    required this.kind,
    required this.sourceUrl,
    this.isExtractedVideoFrames = false,
    this.audioFile,
  }) : files = files ?? (file != null ? [file] : const []);

  File get file => files.first;
}

/// Top-level function executed inside a background [Isolate] so image
/// decoding, resizing, and JPEG compression never block the main UI thread.
Uint8List? _optimizeImageBytesInIsolate(
  Uint8List sourceBytes,
  int maxDimension,
  int quality,
) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;

  final baked = img.bakeOrientation(decoded);
  img.Image processed = baked;
  if (baked.width > maxDimension || baked.height > maxDimension) {
    if (baked.width >= baked.height) {
      processed = img.copyResize(
        baked,
        width: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      processed = img.copyResize(
        baked,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
}

/// Helper utilities for handling, resizing, compressing, downloading from URL
/// (including YouTube Shorts / YouTube videos / OpenGraph media), extracting
/// video keyframes, persisting, and staging media before sending to AI vision.
class MediaUtils {
  static const MethodChannel _mediaChannel =
      MethodChannel('vehicle_damage_analyzer/media');

  /// Optional override hook for unit/widget tests to intercept video frame
  /// extraction without requiring a native device decoder.
  static Future<List<File>> Function(String videoPath, int frameCount)?
      customFrameExtractor;

  /// Optional override hook for unit/widget tests to intercept URL media
  /// downloads without making real network calls.
  static Future<DownloadedMediaResult> Function(String url)?
      customUrlDownloader;

  /// Optional override hook for unit/widget tests to intercept video audio extraction.
  static Future<File?> Function(String videoPath)? customAudioExtractor;

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

  /// Returns a permanent directory for storing report media thumbnails/photos
  /// so they remain accessible in History and Report screens after temp cleanup.
  static Future<Directory> reportMediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'vda_report_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Optimizes and resizes an image file for vision AI analysis inside a
  /// background isolate.
  static Future<File> optimizeImage(
    File sourceFile, {
    int maxDimension = 1280,
    int quality = 82,
  }) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      final compressedBytes = await Isolate.run(
        () => _optimizeImageBytesInIsolate(bytes, maxDimension, quality),
      );
      if (compressedBytes == null) return sourceFile;

      final staging = await stagingDir();
      final baseName = p.basenameWithoutExtension(sourceFile.path);
      final targetPath = p.join(
        staging.path,
        'opt_${DateTime.now().microsecondsSinceEpoch}_$baseName.jpg',
      );
      final outFile = File(targetPath);
      await outFile.writeAsBytes(compressedBytes, flush: true);
      return outFile;
    } catch (_) {
      return sourceFile;
    }
  }

  /// Batch optimizes multiple images with progress reporting.
  static Future<List<File>> optimizeImages(
    List<File> sourceFiles, {
    int maxDimension = 1280,
    int quality = 82,
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <File>[];
    for (int i = 0; i < sourceFiles.length; i++) {
      onProgress?.call(i + 1, sourceFiles.length);
      final opt = await optimizeImage(
        sourceFiles[i],
        maxDimension: maxDimension,
        quality: quality,
      );
      results.add(opt);
    }
    return results;
  }

  /// Encodes a list of image files to base64 strings inside a background isolate
  /// to keep UI animations smooth during payload preparation.
  static Future<List<String>> encodeImagesToBase64(List<File> images) async {
    final paths = images.map((f) => f.path).toList(growable: false);
    return Isolate.run(() async {
      final encoded = <String>[];
      for (final path in paths) {
        final bytes = await File(path).readAsBytes();
        encoded.add(base64Encode(bytes));
      }
      return encoded;
    });
  }

  /// Copies analyzed images into permanent app storage so they remain available
  /// in History and Report screens even after temporary staging is cleared.
  static Future<List<String>> persistReportImages(
    List<File> files,
    String reportId,
  ) async {
    try {
      final dir = await reportMediaDir();
      final savedPaths = <String>[];
      for (int i = 0; i < files.length; i++) {
        final src = files[i];
        if (!await src.exists()) continue;
        final ext =
            p.extension(src.path).isNotEmpty ? p.extension(src.path) : '.jpg';
        final destPath = p.join(dir.path, '${reportId}_$i$ext');
        final copied = await src.copy(destPath);
        savedPaths.add(copied.path);
      }
      return savedPaths;
    } catch (_) {
      return files.map((f) => f.path).toList();
    }
  }

  /// Copies the source inspection video into permanent app storage so the user
  /// can re-watch it in the diagnostic report even after temp staging is cleared.
  static Future<String?> persistReportVideo(
    File videoFile,
    String reportId,
  ) async {
    try {
      if (!await videoFile.exists()) return null;
      final dir = await reportMediaDir();
      final ext = p.extension(videoFile.path).isNotEmpty
          ? p.extension(videoFile.path)
          : '.mp4';
      final destPath = p.join(dir.path, 'video_$reportId$ext');
      final copied = await videoFile.copy(destPath);
      return copied.path;
    } catch (_) {
      return videoFile.path;
    }
  }

  /// Copies the extracted or recorded audio into permanent app storage so the user
  /// can listen to the mechanical vehicle sounds in the diagnostic report.
  static Future<String?> persistReportAudio(
    File audioFile,
    String reportId,
  ) async {
    try {
      if (!await audioFile.exists()) return null;
      final dir = await reportMediaDir();
      final ext = p.extension(audioFile.path).isNotEmpty
          ? p.extension(audioFile.path)
          : '.m4a';
      final destPath = p.join(dir.path, 'audio_$reportId$ext');
      final copied = await audioFile.copy(destPath);
      return copied.path;
    } catch (_) {
      return audioFile.path;
    }
  }

  /// Deletes persisted media files associated with a deleted report.
  static Future<void> deleteReportMedia(List<String> paths) async {
    for (final path in paths) {
      if (path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists() && path.contains('vda_report_media')) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Extracts [frameCount] evenly spaced JPEG keyframes from [videoPath].
  ///
  /// Uses Android's native `MediaMetadataRetriever` via MethodChannel
  /// (`vehicle_damage_analyzer/media`) on Android, with a desktop `ffmpeg` CLI
  /// fallback when running on macOS/Linux/Windows.
  static Future<List<File>> extractFrames(
    String videoPath, {
    int frameCount = 5,
    int maxDimension = 1280,
    int quality = 84,
  }) async {
    if (customFrameExtractor != null) {
      return customFrameExtractor!(videoPath, frameCount);
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists() || await videoFile.length() == 0) {
      throw VideoExtractionException('Video file not found: $videoPath');
    }

    final staging = await stagingDir();

    // 1. Try native platform MethodChannel (Android MediaMetadataRetriever)
    try {
      final rawPaths = await _mediaChannel.invokeMethod<List<dynamic>>(
        'extractVideoFrames',
        {
          'videoPath': videoFile.path,
          'outputDir': staging.path,
          'frameCount': frameCount,
          'maxDimension': maxDimension,
          'quality': quality,
        },
      );
      if (rawPaths != null && rawPaths.isNotEmpty) {
        final files = rawPaths
            .whereType<String>()
            .map((path) => File(path))
            .where((f) => f.existsSync() && f.lengthSync() > 128)
            .toList();
        if (files.isNotEmpty) {
          return files;
        }
      }
    } on MissingPluginException {
      // Fall through to desktop/Dart fallback
    } on PlatformException catch (e) {
      throw VideoExtractionException(
        e.message ?? 'Could not decode keyframes from video.',
      );
    }

    // 2. Desktop fallback: if running on macOS/Linux/Windows with ffmpeg installed
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      try {
        final prefix = p.join(
          staging.path,
          'ff_frame_${DateTime.now().millisecondsSinceEpoch}',
        );
        final proc = await Process.run('ffmpeg', [
          '-y',
          '-i',
          videoFile.path,
          '-vf',
          'fps=1,scale=\'min($maxDimension,iw)\':-2',
          '-frames:v',
          '$frameCount',
          '-q:v',
          '3',
          '${prefix}_%02d.jpg',
        ]);
        if (proc.exitCode == 0) {
          final extracted = <File>[];
          for (int i = 1; i <= frameCount; i++) {
            final idx = i.toString().padLeft(2, '0');
            final f = File('${prefix}_$idx.jpg');
            if (await f.exists() && await f.length() > 128) {
              extracted.add(f);
            }
          }
          if (extracted.isNotEmpty) {
            return extracted;
          }
        }
      } catch (_) {}
    }

    throw VideoExtractionException();
  }

  /// Extracts the audio track from [videoPath] as an MP3 or WAV file.
  /// Uses native method channel where supported, or desktop `ffmpeg` CLI.
  /// Returns `null` if the video has no audio track or extraction is unavailable.
  static Future<File?> extractAudioFromVideo(String videoPath) async {
    if (customAudioExtractor != null) {
      return customAudioExtractor!(videoPath);
    }
    // If unit/widget test mocked frame extraction without configuring an audio extractor, skip
    if (customFrameExtractor != null) {
      return null;
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists() || await videoFile.length() < 1024) {
      return null;
    }

    final staging = await stagingDir();
    final ext = Platform.isAndroid ? '.m4a' : '.mp3';
    final outPath = p.join(
      staging.path,
      'audio_${DateTime.now().millisecondsSinceEpoch}$ext',
    );

    // 1. Try native platform MethodChannel
    try {
      final rawPath = await _mediaChannel.invokeMethod<String>(
        'extractAudioTrack',
        {
          'videoPath': videoFile.path,
          'outputPath': outPath,
        },
      );
      if (rawPath != null) {
        final f = File(rawPath);
        if (await f.exists() && await f.length() > 512) {
          return f;
        }
      }
    } on MissingPluginException {
      // Desktop fallback
    } catch (_) {}

    // 2. Desktop fallback (macOS / Linux / Windows) using ffmpeg
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      try {
        final proc = await Process.run('ffmpeg', [
          '-y',
          '-i',
          videoFile.path,
          '-vn',
          '-acodec',
          'libmp3lame',
          '-q:a',
          '4',
          outPath,
        ]);
        if (proc.exitCode == 0) {
          final f = File(outPath);
          if (await f.exists() && await f.length() > 512) {
            return f;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Encodes any single file (e.g. an extracted audio track) to base64.
  static Future<String> encodeFileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Extracts the 11-character YouTube video ID if [rawUrl] is a YouTube
  /// Watch, Shorts, Embed, Live, or `youtu.be` link.
  static String? extractYouTubeVideoId(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final isYouTube = host == 'youtu.be' ||
        host.endsWith('youtube.com') ||
        host.endsWith('youtube-nocookie.com');
    if (!isYouTube) return null;

    // 1. Query param ?v=<ID>
    final vParam = uri.queryParameters['v'];
    if (vParam != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(vParam)) {
      return vParam;
    }

    // 2. Path segments: /shorts/<ID>, /embed/<ID>, /live/<ID>, /v/<ID>, or youtu.be/<ID>
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (host == 'youtu.be' && segments.isNotEmpty) {
      final candidate = segments.first;
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
        return candidate;
      }
    }
    if (segments.length >= 2) {
      final prefix = segments[0].toLowerCase();
      final candidate = segments[1];
      if ((prefix == 'shorts' ||
              prefix == 'embed' ||
              prefix == 'live' ||
              prefix == 'v') &&
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// Normalizes common cloud-sharing URLs (Google Drive, Dropbox) into direct
  /// binary download URLs.
  static String normalizeMediaUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final driveMatch = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)')
        .firstMatch(trimmed);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    if (trimmed.contains('dropbox.com/') && trimmed.contains('dl=0')) {
      return trimmed.replaceAll('dl=0', 'dl=1');
    }
    return trimmed;
  }

  /// Inspects magic bytes, HTTP `Content-Type`, and URL extension to classify
  /// a downloaded media payload as an image or a video.
  static DownloadedMediaKind? detectMediaKind({
    required Uint8List bytes,
    String? contentType,
    String? url,
  }) {
    if (bytes.length >= 12) {
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return DownloadedMediaKind.image;
      }
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return DownloadedMediaKind.image;
      }
      // GIF: GIF87a / GIF89a
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return DownloadedMediaKind.image;
      }
      // WebP: RIFF....WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return DownloadedMediaKind.image;
      }
      // BMP: BM
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return DownloadedMediaKind.image;
      }
      // MP4 / MOV / M4V / 3GP: ....ftyp at offset 4
      if (bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return DownloadedMediaKind.video;
      }
      // WebM / MKV: 1A 45 DF A3
      if (bytes[0] == 0x1A &&
          bytes[1] == 0x45 &&
          bytes[2] == 0xDF &&
          bytes[3] == 0xA3) {
        return DownloadedMediaKind.video;
      }
      // AVI: RIFF....AVI
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x41 &&
          bytes[9] == 0x56 &&
          bytes[10] == 0x49) {
        return DownloadedMediaKind.video;
      }
    }

    final ct = (contentType ?? '').toLowerCase();
    if (ct.startsWith('image/')) return DownloadedMediaKind.image;
    if (ct.startsWith('video/')) return DownloadedMediaKind.video;

    final pathLower = (Uri.tryParse(url ?? '')?.path ?? url ?? '').toLowerCase();
    if (pathLower.endsWith('.jpg') ||
        pathLower.endsWith('.jpeg') ||
        pathLower.endsWith('.png') ||
        pathLower.endsWith('.webp') ||
        pathLower.endsWith('.bmp') ||
        pathLower.endsWith('.gif')) {
      return DownloadedMediaKind.image;
    }
    if (pathLower.endsWith('.mp4') ||
        pathLower.endsWith('.mov') ||
        pathLower.endsWith('.m4v') ||
        pathLower.endsWith('.webm') ||
        pathLower.endsWith('.mkv') ||
        pathLower.endsWith('.avi')) {
      return DownloadedMediaKind.video;
    }

    return null;
  }

  /// Downloads 4 distinct high-resolution timeline keyframes for a YouTube
  /// video or YouTube Short (`maxresdefault`, `maxres1`, `maxres2`, `maxres3`
  /// with automatic fallback to `sddefault` and `hq1`..`hq3`).
  static Future<DownloadedMediaResult> _downloadYouTubeKeyframes({
    required String videoId,
    required String sourceUrl,
    required Dio client,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final slotCandidates = <List<String>>[
      [
        'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
        'https://i.ytimg.com/vi/$videoId/sddefault.jpg',
        'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      ],
      [
        'https://i.ytimg.com/vi/$videoId/maxres1.jpg',
        'https://i.ytimg.com/vi/$videoId/hq1.jpg',
      ],
      [
        'https://i.ytimg.com/vi/$videoId/maxres2.jpg',
        'https://i.ytimg.com/vi/$videoId/hq2.jpg',
      ],
      [
        'https://i.ytimg.com/vi/$videoId/maxres3.jpg',
        'https://i.ytimg.com/vi/$videoId/hq3.jpg',
      ],
    ];

    final staging = await stagingDir();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final savedFiles = <File>[];
    final seenFingerprints = <String>{};

    for (int slot = 0; slot < slotCandidates.length; slot++) {
      onReceiveProgress?.call(slot, slotCandidates.length);
      for (final candidateUrl in slotCandidates[slot]) {
        try {
          final resp = await client.get<List<int>>(
            candidateUrl,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (status) => status != null && status == 200,
            ),
          );
          final data = resp.data;
          // Reject tiny placeholder thumbnails (< 2KB)
          if (data != null && data.length > 2048) {
            final bytes = Uint8List.fromList(data);
            final fingerprint =
                '${bytes.length}_${bytes[bytes.length ~/ 2]}_${bytes[bytes.length ~/ 3]}';
            if (seenFingerprints.add(fingerprint)) {
              final rawFile = File(
                p.join(staging.path, 'yt_${videoId}_${ts}_$slot.jpg'),
              );
              await rawFile.writeAsBytes(bytes, flush: true);
              final optFile = await optimizeImage(rawFile);
              savedFiles.add(optFile);
            }
            break;
          }
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) rethrow;
        }
      }
    }

    onReceiveProgress?.call(slotCandidates.length, slotCandidates.length);

    if (savedFiles.isEmpty) {
      throw const UrlMediaDownloadException(
        'Could not extract keyframes from this YouTube video. Please verify the video is public.',
      );
    }

    return DownloadedMediaResult(
      files: savedFiles,
      kind: DownloadedMediaKind.image,
      sourceUrl: sourceUrl,
      isExtractedVideoFrames: true,
    );
  }

  /// Extracts an embedded direct video or image URL from an HTML webpage's
  /// OpenGraph / Twitter Card meta tags (`og:video`, `og:image`, etc.).
  static String? extractEmbeddedMediaUrlFromHtml(
    String html,
    Uri baseUri,
  ) {
    final patterns = <RegExp>[
      RegExp(
        r'''<meta[^>]+property=["']og:video(?::secure_url|:url)?["'][^>]+content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:video(?::secure_url|:url)?["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+property=["']og:image(?::secure_url|:url)?["'][^>]+content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image(?::secure_url|:url)?["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta[^>]+name=["']twitter:image(?::src)?["'][^>]+content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(html);
      final raw = match?.group(1)?.trim();
      if (raw != null && raw.isNotEmpty) {
        final decoded = raw.replaceAll('&amp;', '&');
        final resolved = baseUri.resolve(decoded).toString();
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          return resolved;
        }
      }
    }
    return null;
  }

  /// Downloads an image, video, or YouTube Short/video from a remote HTTP/HTTPS
  /// [url], stages it locally, and optimizes/extracts keyframes for AI analysis.
  static Future<DownloadedMediaResult> downloadMediaFromUrl(
    String url, {
    Dio? dio,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (customUrlDownloader != null) {
      return customUrlDownloader!(url.trim());
    }

    final normalizedUrl = normalizeMediaUrl(url);
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const UrlMediaDownloadException(
        'Invalid URL. Please enter a valid http:// or https:// image or video link.',
      );
    }

    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 45),
            followRedirects: true,
            maxRedirects: 5,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              'Accept': 'image/*,video/*,text/html,*/*;q=0.8',
            },
          ),
        );

    // 1. Handle YouTube Shorts / YouTube Watch / youtu.be links directly
    final ytVideoId = extractYouTubeVideoId(normalizedUrl);
    if (ytVideoId != null) {
      return _downloadYouTubeKeyframes(
        videoId: ytVideoId,
        sourceUrl: normalizedUrl,
        client: client,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    }

    try {
      final response = await client.get<List<int>>(
        normalizedUrl,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: Options(responseType: ResponseType.bytes),
      );

      final data = response.data;
      if (data == null || data.length < 64) {
        throw const UrlMediaDownloadException(
          'Downloaded file is empty or too small to be a valid image or video.',
        );
      }

      final bytes = Uint8List.fromList(data);
      final contentType =
          (response.headers.value(Headers.contentTypeHeader) ?? '')
              .toLowerCase();

      // 2. If the response is an HTML webpage, inspect OpenGraph / Twitter meta tags
      if (contentType.contains('text/html')) {
        final htmlStr = utf8.decode(bytes, allowMalformed: true);
        final embeddedUrl = extractEmbeddedMediaUrlFromHtml(htmlStr, uri);
        if (embeddedUrl != null && embeddedUrl != normalizedUrl) {
          return downloadMediaFromUrl(
            embeddedUrl,
            dio: client,
            cancelToken: cancelToken,
            onReceiveProgress: onReceiveProgress,
          );
        }
      }

      final kind = detectMediaKind(
        bytes: bytes,
        contentType: contentType,
        url: normalizedUrl,
      );

      final staging = await stagingDir();
      final ts = DateTime.now().microsecondsSinceEpoch;

      // If kind is still unknown, try decoding as an image in an isolate
      if (kind == null) {
        final optimizedBytes = await Isolate.run(
          () => _optimizeImageBytesInIsolate(bytes, 1280, 82),
        );
        if (optimizedBytes != null) {
          final imgFile = File(p.join(staging.path, 'url_img_$ts.jpg'));
          await imgFile.writeAsBytes(optimizedBytes, flush: true);
          return DownloadedMediaResult(
            file: imgFile,
            kind: DownloadedMediaKind.image,
            sourceUrl: normalizedUrl,
          );
        }
        throw const UrlMediaDownloadException(
          'The URL did not return a direct image (JPG/PNG/WebP), video (MP4/MOV), or supported YouTube link.',
        );
      }

      if (kind == DownloadedMediaKind.image) {
        final rawFile = File(p.join(staging.path, 'url_raw_$ts.jpg'));
        await rawFile.writeAsBytes(bytes, flush: true);
        final optimizedFile = await optimizeImage(rawFile);
        return DownloadedMediaResult(
          file: optimizedFile,
          kind: DownloadedMediaKind.image,
          sourceUrl: normalizedUrl,
        );
      } else {
        final pathExt = p.extension(uri.path).toLowerCase();
        final ext = (pathExt == '.mov' ||
                pathExt == '.webm' ||
                pathExt == '.mkv' ||
                pathExt == '.avi')
            ? pathExt
            : '.mp4';
        final videoFile = File(p.join(staging.path, 'url_video_$ts$ext'));
        await videoFile.writeAsBytes(bytes, flush: true);
        File? audioTrack;
        try {
          audioTrack = await extractAudioFromVideo(videoFile.path);
        } catch (_) {}
        return DownloadedMediaResult(
          file: videoFile,
          kind: DownloadedMediaKind.video,
          sourceUrl: normalizedUrl,
          audioFile: audioTrack,
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const UrlMediaDownloadException('Download cancelled.');
      }
      final code = e.response?.statusCode;
      throw UrlMediaDownloadException(
        code != null
            ? 'Failed to download media from URL (HTTP $code).'
            : 'Network error while downloading media from URL. Please check the link and internet connection.',
      );
    }
  }

  /// Cleans up temporary per-analysis `opt_*` files while preserving any
  /// URL-downloaded or video-extracted media still staged on CaptureScreen.
  static Future<void> clearStaging() async {
    try {
      final dir = await stagingDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && p.basename(entity.path).startsWith('opt_')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
