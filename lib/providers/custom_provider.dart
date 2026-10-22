import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import '../utils/media_utils.dart';
import 'ai_provider.dart';
import 'openai_provider.dart';
import 'json_extractor.dart';

/// For users pointing at their own self-hosted vision model / gateway.
/// Defaults to the OpenAI-compatible chat/completions shape (used by many
/// self-hosted servers like vLLM, LM Studio, Ollama's OpenAI shim, etc.)
/// but sends whatever baseUrl + headers the user configured, and falls
/// back to a raw-response passthrough if the JSON shape differs slightly.
class CustomProvider extends AIProvider {
  const CustomProvider(super.config);

  /// Loads model ids from the OpenAI-compatible `/models` endpoint.
  @override
  Future<List<String>> loadModels() async {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      headers: {
        if (config.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
        ...config.extraHeaders,
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final response = await dio.get('/models');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((model) => model['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
      if (data['models'] is List) {
        return (data['models'] as List)
            .whereType<Map>()
            .map((model) => (model['name'] ?? model['id'])?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
    }
    throw const FormatException(
        'The custom provider returned an unexpected /models response format.');
  }

  @override
  Future<DamageReport> analyzeImages(
    List<File> images, {
    File? audioFile,
    String? extraContext,
    CancelToken? cancelToken,
  }) async {
    final delegate = OpenAIProvider(config);
    try {
      return await delegate.analyzeImages(
        images,
        audioFile: audioFile,
        extraContext: extraContext,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      final dio = Dio(BaseOptions(
        baseUrl: config.baseUrl,
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          ...config.extraHeaders,
        },
      ));
      final encoded = await MediaUtils.encodeImagesToBase64([images.first]);
      final response = await dio.post(
        '/analyze',
        cancelToken: cancelToken,
        data: {
          'model': config.model,
          'image_base64': encoded.first,
          'prompt': kDamageAnalysisPrompt,
        },
      );

      final raw = response.data.toString();
      Map<String, dynamic> json;
      try {
        json = extractJsonObject(raw);
      } catch (_) {
        json = {
          'summary': 'Could not parse custom provider response.',
          'items': []
        };
      }

      final items = (json['items'] as List<dynamic>? ?? [])
          .map((e) => DamageItem.fromJson(e as Map<String, dynamic>))
          .toList();

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
      }

      return DamageReport(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        sourceMediaPath: images.first.path,
        mediaPaths: images.map((f) => f.path).toList(),
        providerLabel: label,
        modelUsed: config.model,
        items: items,
        overallConfidence: items.isEmpty
            ? 0.0
            : items.map((e) => e.confidence).reduce((a, b) => a + b) /
                items.length,
        rawModelResponse: raw,
        summary: json['summary']?.toString(),
        summaryKhmer: json['summary_km']?.toString(),
        vehicleIdentity: parsedIdentity,
        healthAssessment: parsedHealth,
        acousticAnalysis: parsedAcoustic,
      );
    }
  }
}
