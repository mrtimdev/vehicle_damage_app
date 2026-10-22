import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_localizations.dart';

/// Immutable state for the Text-to-Speech (Listen) audio controller.
class TtsState {
  final String? activeId;
  final String? activeLangCode;
  final bool isLoading;
  final bool isPlaying;
  final String? errorMessage;

  const TtsState({
    this.activeId,
    this.activeLangCode,
    this.isLoading = false,
    this.isPlaying = false,
    this.errorMessage,
  });

  bool isActive(String id) => activeId == id && (isLoading || isPlaying);

  TtsState copyWith({
    String? activeId,
    String? activeLangCode,
    bool? isLoading,
    bool? isPlaying,
    String? errorMessage,
    bool clearActive = false,
    bool clearError = false,
  }) {
    return TtsState(
      activeId: clearActive ? null : (activeId ?? this.activeId),
      activeLangCode:
          clearActive ? null : (activeLangCode ?? this.activeLangCode),
      isLoading: clearActive ? false : (isLoading ?? this.isLoading),
      isPlaying: clearActive ? false : (isPlaying ?? this.isPlaying),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Optional override hook for widget tests to intercept TTS requests without
/// hitting network or native platform channels.
typedef TtsSpeakHandler = Future<void> Function(
  String id,
  String text,
  String langCode,
);

/// Riverpod provider for listening to Khmer (`km`) and English (`en`) results.
final ttsControllerProvider =
    StateNotifierProvider<TtsController, TtsState>((ref) {
  return TtsController();
});

class TtsController extends StateNotifier<TtsState> {
  static const MethodChannel _nativeChannel =
      MethodChannel('vehicle_damage_analyzer/tts');

  final Dio _dio;
  final TtsSpeakHandler? customSpeakHandler;
  VideoPlayerController? _playerController;
  CancelToken? _cancelToken;
  int _sessionCounter = 0;

  TtsController({
    Dio? dio,
    this.customSpeakHandler,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                  'Referer': 'https://translate.google.com/',
                },
              ),
            ),
        super(const TtsState());

  /// Toggles audio playback for [id]. If [id] is already active, stops it.
  /// Otherwise, stops any current playback and reads [text] aloud in [langCode]
  /// (`'km'` for Khmer or `'en'` for English).
  Future<void> toggleSpeak({
    required String id,
    required String text,
    required String langCode,
  }) async {
    if (state.isActive(id)) {
      await stop();
      return;
    }

    await stop();

    final cleanedText = langCode == 'km'
        ? KhmerAutomotiveTranslator.sanitizeKhmer(text)
        : text.trim();
    if (cleanedText.isEmpty) return;

    final sessionId = ++_sessionCounter;
    state = TtsState(
      activeId: id,
      activeLangCode: langCode,
      isLoading: true,
      isPlaying: false,
    );

    if (customSpeakHandler != null) {
      state = state.copyWith(isLoading: false, isPlaying: true);
      await customSpeakHandler!(id, cleanedText, langCode);
      return;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      final cacheDir = await _getCacheDirectory();
      File? combinedAudioFile;

      try {
        combinedAudioFile = await _fetchOrBuildCombinedMp3(
          fullText: cleanedText,
          langCode: langCode,
          cacheDir: cacheDir,
          cancelToken: cancelToken,
          sessionId: sessionId,
        );
      } catch (networkErr) {
        if (networkErr is DioException && CancelToken.isCancel(networkErr)) {
          return;
        }
        debugPrint('Network TTS fetch failed, trying native TTS: $networkErr');
      }

      if (!mounted || sessionId != _sessionCounter) return;

      state = state.copyWith(isLoading: false, isPlaying: true);

      if (combinedAudioFile != null && combinedAudioFile.existsSync()) {
        await _playAudioFileAndWait(combinedAudioFile, sessionId);
      } else {
        // Fallback to offline native device TTS if network download was unavailable
        await _nativeChannel.invokeMethod('speakNative', {
          'text': cleanedText,
          'langCode': langCode,
        });
      }

      if (mounted && sessionId == _sessionCounter) {
        state = const TtsState();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      debugPrint('TTS playback error ($langCode): $e');
      if (mounted && sessionId == _sessionCounter) {
        state = TtsState(
          errorMessage: langCode == 'km'
              ? 'មិនអាចចាក់សំឡេងបានទេ សូមពិនិត្យកម្រិតសំឡេង និងអ៊ីនធឺណិតរបស់អ្នក។'
              : 'Unable to play audio readout. Please check device volume and connection.',
        );
      }
    }
  }

  /// Stops any active speech playback immediately.
  Future<void> stop() async {
    _sessionCounter++;
    _cancelToken?.cancel('User stopped TTS');
    _cancelToken = null;

    if (customSpeakHandler == null) {
      try {
        await _nativeChannel.invokeMethod('stop');
      } catch (_) {}
    }

    final prevController = _playerController;
    _playerController = null;
    if (prevController != null) {
      try {
        await prevController.pause();
        await prevController.dispose();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      state = const TtsState();
    }
  }

  /// Splits long Khmer or English text into natural sentence chunks (<= 175 chars)
  /// so the TTS endpoint synthesizes each phrase smoothly without truncation.
  @visibleForTesting
  static List<String> splitTextIntoSpeechChunks(
    String text, {
    int maxChunkLength = 175,
  }) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];
    if (normalized.length <= maxChunkLength) return [normalized];

    final chunks = <String>[];
    // Split on Khmer full stop (។), English period/semicolon/colon, or newline
    final rawSentences = normalized.split(RegExp(r'(?<=[។.!?;:])\s*'));
    final buffer = StringBuffer();

    void flushBuffer() {
      final str = buffer.toString().trim();
      if (str.isNotEmpty) {
        chunks.add(str);
      }
      buffer.clear();
    }

    for (final sentence in rawSentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (buffer.isEmpty && s.length <= maxChunkLength) {
        buffer.write(s);
      } else if (buffer.length + 1 + s.length <= maxChunkLength) {
        buffer.write(' ');
        buffer.write(s);
      } else {
        flushBuffer();
        if (s.length <= maxChunkLength) {
          buffer.write(s);
        } else {
          int start = 0;
          while (start < s.length) {
            int end = (start + maxChunkLength).clamp(0, s.length);
            if (end < s.length) {
              final lastSpace = s.lastIndexOf(' ', end);
              if (lastSpace > start + 40) {
                end = lastSpace;
              }
            }
            final sub = s.substring(start, end).trim();
            if (sub.isNotEmpty) chunks.add(sub);
            start = end;
          }
        }
      }
    }
    flushBuffer();
    return chunks;
  }

  Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/vda_tts_cache');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeHashFor(String langCode, String text) {
    final keyBytes = utf8.encode('$langCode|$text');
    final hash = base64Url
        .encode(keyBytes)
        .replaceAll('=', '')
        .replaceAll('/', '_')
        .replaceAll('+', '-');
    return hash.length > 48
        ? '${hash.substring(0, 48)}_${keyBytes.length}'
        : hash;
  }

  /// Downloads all sentence chunks for [fullText] and concatenates their MP3
  /// frames into a single seamless `.mp3` file so the audio player only
  /// initializes once and never cuts off between sentences.
  Future<File> _fetchOrBuildCombinedMp3({
    required String fullText,
    required String langCode,
    required Directory cacheDir,
    required CancelToken cancelToken,
    required int sessionId,
  }) async {
    final combinedHash = _safeHashFor(langCode, fullText);
    final combinedFile =
        File('${cacheDir.path}/tts_full_${langCode}_$combinedHash.mp3');

    if (combinedFile.existsSync() && combinedFile.lengthSync() > 256) {
      return combinedFile;
    }

    final chunks = splitTextIntoSpeechChunks(fullText);
    final combinedBytes = BytesBuilder(copy: false);

    for (final chunk in chunks) {
      if (!mounted || sessionId != _sessionCounter) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(path: ''),
          reason: 'Session cancelled',
        );
      }
      final chunkBytes = await _fetchChunkBytes(
        chunk: chunk,
        langCode: langCode,
        cancelToken: cancelToken,
      );
      combinedBytes.add(chunkBytes);
    }

    final bytes = combinedBytes.takeBytes();
    if (bytes.length <= 128) {
      throw Exception('Downloaded TTS audio was empty');
    }
    await combinedFile.writeAsBytes(bytes, flush: true);
    return combinedFile;
  }

  Future<List<int>> _fetchChunkBytes({
    required String chunk,
    required String langCode,
    required CancelToken cancelToken,
  }) async {
    final encodedText = Uri.encodeComponent(chunk);
    final urls = [
      'https://translate.googleapis.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$langCode&q=$encodedText',
      'https://translate.google.com/translate_tts?ie=UTF-8&client=gtx&tl=$langCode&q=$encodedText',
    ];

    Object? lastErr;
    for (final url in urls) {
      try {
        final response = await _dio.get<List<int>>(
          url,
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes != null && bytes.length > 128) {
          return bytes;
        }
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) rethrow;
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('Failed to download TTS audio for $langCode');
  }

  Future<void> _playAudioFileAndWait(File audioFile, int sessionId) async {
    // 1. Try native Android MediaPlayer channel first (avoids ExoPlayer MediaCodec warnings)
    try {
      await _nativeChannel.invokeMethod('playFile', {
        'path': audioFile.path,
      });
      return;
    } on MissingPluginException {
      // Native channel not registered in current running APK build; fall back to VideoPlayerController
    } catch (e) {
      debugPrint('Native MediaPlayer channel error, using fallback: $e');
    }

    if (!mounted || sessionId != _sessionCounter) return;

    // 2. Fallback: VideoPlayerController on the single combined MP3 file
    final prev = _playerController;
    _playerController = null;
    if (prev != null) {
      try {
        await prev.pause();
        await prev.dispose();
      } catch (_) {}
      // Allow Android ExoPlayer & AudioFocusManager to finish releasing
      // before initializing the next AudioTrack so gain is never -inf dB.
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    if (!mounted || sessionId != _sessionCounter) return;

    final controller = VideoPlayerController.file(audioFile);
    _playerController = controller;
    await controller.initialize();

    if (!mounted || sessionId != _sessionCounter) {
      await controller.dispose();
      return;
    }

    await controller.setLooping(false);
    await controller.setVolume(1.0);

    // Google Translate TTS MP3s are 64kbps (8000 bytes/sec). Calculate a minimum
    // expected playback duration from the file byte size so raw MP3 streams
    // without an Xing header never complete prematurely on the first tick.
    final fileBytes = audioFile.lengthSync();
    final estimatedMs = ((fileBytes / 8000.0) * 1000).round();
    final minPlayDuration = Duration(
      milliseconds: (estimatedMs - 400).clamp(600, 120000),
    );
    final startedAt = DateTime.now();

    final completer = Completer<void>();
    void listener() {
      if (!controller.value.isInitialized) return;
      final val = controller.value;
      if (val.hasError) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(val.errorDescription ?? 'Playback error'),
          );
        }
        return;
      }

      final elapsed = DateTime.now().difference(startedAt);
      if (val.isCompleted && elapsed >= minPlayDuration) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (val.duration > const Duration(seconds: 1) &&
          val.position >= val.duration - const Duration(milliseconds: 50) &&
          elapsed >= minPlayDuration) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    controller.addListener(listener);
    await controller.play();
    // Re-assert full volume shortly after play() starts in case audio focus
    // transition ducked or muted the initial track gain.
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted &&
          sessionId == _sessionCounter &&
          _playerController == controller &&
          controller.value.isInitialized) {
        controller.setVolume(1.0);
      }
    });

    // Also schedule a timer for the estimated duration in case ExoPlayer does
    // not report accurate duration metadata for raw concatenated MP3 frames.
    final fallbackWait = Duration(
      milliseconds: (estimatedMs + 600).clamp(1500, 120000),
    );

    try {
      await completer.future.timeout(fallbackWait, onTimeout: () {});
    } finally {
      controller.removeListener(listener);
      if (_playerController == controller) {
        _playerController = null;
      }
      try {
        await controller.pause();
        await controller.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sessionCounter++;
    _cancelToken?.cancel();
    _playerController?.dispose();
    super.dispose();
  }
}
