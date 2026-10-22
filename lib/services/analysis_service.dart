import 'dart:io';
import 'package:dio/dio.dart';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';
import '../providers/provider_factory.dart';
import '../utils/auto_part_cropper.dart';
import '../utils/media_utils.dart';
import 'history_service.dart';

/// Exception thrown when analysis is requested but no valid AI provider
/// has been configured yet.
class ProviderNotConfiguredException implements Exception {
  final String message;
  ProviderNotConfiguredException([
    this.message = 'No AI provider configured. Please set one up in Settings.',
  ]);
  @override
  String toString() => message;
}

/// High-level entry point the UI calls: given a config and some media
/// files, runs the analysis through the right provider adapter, persists
/// the inspected photos permanently, and saves the result to local history.
class AnalysisService {
  final HistoryService _historyService = HistoryService();

  Future<DamageReport> analyze({
    required AIProviderConfig? config,
    required List<File> images,
    File? videoFile,
    File? audioFile,
    String? extraContext,
    bool enableAutoCrop = true,
    CancelToken? cancelToken,
  }) async {
    if (config == null || !config.isValid) {
      throw ProviderNotConfiguredException();
    }
    final provider = AIProviderFactory.build(config);
    final rawReport = await provider.analyzeImages(
      images,
      audioFile: audioFile,
      extraContext: extraContext,
      cancelToken: cancelToken,
    );

    // Persist inspected images into permanent storage so they survive temp staging cleanup
    final persistedPaths = await MediaUtils.persistReportImages(
      images,
      rawReport.id,
    );

    // Persist video and audio files so they remain viewable/playable in the report
    String? persistedVideoPath;
    if (videoFile != null) {
      persistedVideoPath =
          await MediaUtils.persistReportVideo(videoFile, rawReport.id);
    }
    String? persistedAudioPath;
    if (audioFile != null) {
      persistedAudioPath =
          await MediaUtils.persistReportAudio(audioFile, rawReport.id);
    }

    final report = rawReport.copyWith(
      sourceMediaPath: persistedPaths.isNotEmpty
          ? persistedPaths.first
          : rawReport.sourceMediaPath,
      mediaPaths:
          persistedPaths.isNotEmpty ? persistedPaths : rawReport.mediaPaths,
      videoPath: persistedVideoPath ?? rawReport.videoPath,
      audioPath: persistedAudioPath ?? rawReport.audioPath,
    );

    // Auto-crop parts (Tires, Hydraulic lines, Brakes, Engine, Dents, etc.) for items with bounding boxes if enabled
    final finalReport = enableAutoCrop
        ? await AutoPartCropper.cropReportParts(report)
        : report;

    await _historyService.save(finalReport);
    return finalReport;
  }
}
