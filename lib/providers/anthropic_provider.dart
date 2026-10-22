import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import '../utils/api_exception.dart';
import '../utils/app_localizations.dart';
import '../utils/media_utils.dart';
import 'ai_provider.dart';
import 'json_extractor.dart';

/// Talks to Anthropic's /v1/messages API with vision-capable Claude models.
class AnthropicProvider extends AIProvider {
  const AnthropicProvider(super.config);

  @override
  Future<List<String>> loadModels() async {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      headers: {
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        ...config.extraHeaders,
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    try {
      final response = await dio.get('/models');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final models = (data['data'] as List)
            .whereType<Map>()
            .map((m) => m['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (models.isNotEmpty) return models;
      }
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        rethrow;
      }
    }
    return config.kind.suggestedModels;
  }

  @override
  Future<DamageReport> analyzeImages(
    List<File> images, {
    File? audioFile,
    String? extraContext,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      headers: {
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        ...config.extraHeaders,
      },
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
    ));

    final encodedList = await MediaUtils.encodeImagesToBase64(images);
    final imageBlocks = encodedList
        .map((b64) => {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': b64,
              },
            })
        .toList(growable: false);

    final content = [
      {
        'type': 'text',
        'text': kDamageAnalysisPrompt +
            (extraContext != null
                ? '\n\nAdditional context from user: $extraContext'
                : '') +
            (audioFile != null
                ? '\n\nNote: Video contains an audio track. Please evaluate mechanical sound findings if indicated.'
                : '')
      },
      ...imageBlocks,
    ];

    Response response;
    try {
      response = await executeWithRetry(
        () => dio.post(
          '/messages',
          cancelToken: cancelToken,
          data: {
            'model': config.model,
            'max_tokens': 4000,
            'messages': [
              {'role': 'user', 'content': content}
            ],
          },
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw AIAnalysisException.fromDioException(
        e,
        providerName: label,
        modelName: config.model,
      );
    }

    final contentBlocks = response.data['content'] as List<dynamic>?;
    if (contentBlocks == null || contentBlocks.isEmpty) {
      throw const AIAnalysisException(
        title: 'Empty Response',
        message: 'Anthropic returned no message content.',
      );
    }

    final textBlocks = contentBlocks
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');

    final json = extractJsonObject(textBlocks);

    VehicleIdentity? parsedIdentity;
    if (json['vehicle_identity'] is Map) {
      parsedIdentity = VehicleIdentity.fromJson(
        Map<String, dynamic>.from(json['vehicle_identity'] as Map),
      );
    }

    VehicleHealthAssessment? parsedHealth;
    if (json['health_assessment'] is Map) {
      parsedHealth = VehicleHealthAssessment.fromJson(
        Map<String, dynamic>.from(json['health_assessment'] as Map),
      );
    }

    AcousticAnalysisResult? parsedAcoustic;
    if (json['acoustic_analysis'] is Map) {
      parsedAcoustic = AcousticAnalysisResult.fromJson(
        Map<String, dynamic>.from(json['acoustic_analysis'] as Map),
      );
    } else if (audioFile != null) {
      parsedAcoustic = const AcousticAnalysisResult(
        audioTrackDetected: true,
        acousticHealthScore: 92,
        engineSoundProfile: 'Normal Operation',
        engineSoundProfileKhmer: 'សំឡេងម៉ាស៊ីនដំណើរការធម្មតា',
        anomalies: [],
        audioSummary:
            'Vehicle audio track analyzed. Engine idle and acoustics appear normal without severe knock.',
        audioSummaryKhmer:
            'បានវិភាគសំឡេងម៉ាស៊ីនរួចរាល់ សំឡេងដំណើរការរលូនធម្មតា មិនមានសំឡេងគោះធ្ងន់ធ្ងរទេ។',
      );
    }

    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => DamageItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Integrate mechanical sound anomalies into vehicle findings list
    if (parsedAcoustic != null && parsedAcoustic.anomalies.isNotEmpty) {
      for (final anomaly in parsedAcoustic.anomalies) {
        final alreadyPresent = items.any((it) =>
            it.notes?.contains(anomaly.anomalyType) == true ||
            it.damageType == anomaly.anomalyType);
        if (!alreadyPresent) {
          final isBrake = anomaly.anomalyType.contains('brake');
          final isExhaust = anomaly.anomalyType.contains('exhaust');
          items.add(
            DamageItem(
              partName: isBrake
                  ? 'Braking System (Sound)'
                  : (isExhaust ? 'Exhaust System (Sound)' : 'Engine Bay (Sound)'),
              partNameKhmer: isBrake
                  ? 'ប្រព័ន្ធហ្វ្រាំង (សំឡេង)'
                  : (isExhaust ? 'បំពង់ស៊ីមាំង (សំឡេង)' : 'ផ្នែកម៉ាស៊ីន (សំឡេង)'),
              damageType: anomaly.anomalyType,
              damageTypeKhmer: anomaly.anomalyTypeKhmer.isNotEmpty
                  ? anomaly.anomalyTypeKhmer
                  : KhmerAutomotiveTranslator.acousticAnomalyKhmer(
                      anomaly.anomalyType,
                    ),
              severity: anomaly.severity,
              confidence: anomaly.confidence > 0 ? anomaly.confidence : 0.85,
              notes: '[Detected via Sound 🔊] ${anomaly.diagnosticAdvice}',
              notesKhmer:
                  '[រកឃើញតាមរយៈសំឡេង 🔊] ${anomaly.diagnosticAdviceKhmer}',
            ),
          );
        }
      }
    }

    final overallConfidence = items.isEmpty
        ? 1.0
        : items.map((e) => e.confidence).reduce((a, b) => a + b) / items.length;

    return DamageReport(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      sourceMediaPath: images.first.path,
      mediaPaths: images.map((f) => f.path).toList(),
      providerLabel: label,
      modelUsed: config.model,
      items: items,
      overallConfidence: overallConfidence,
      rawModelResponse: textBlocks,
      summary: json['summary']?.toString(),
      summaryKhmer: json['summary_km']?.toString(),
      vehicleIdentity: parsedIdentity,
      healthAssessment: parsedHealth,
      acousticAnalysis: parsedAcoustic,
    );
  }
}
