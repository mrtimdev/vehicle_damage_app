import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import 'ai_provider.dart';
import 'openai_provider.dart';
import 'json_extractor.dart';
import 'dart:convert';

/// For users pointing at their own self-hosted vision model / gateway.
/// Defaults to the OpenAI-compatible chat/completions shape (used by many
/// self-hosted servers like vLLM, LM Studio, Ollama's OpenAI shim, etc.)
/// but sends whatever baseUrl + headers the user configured, and falls
/// back to a raw-response passthrough if the JSON shape differs slightly.
class CustomProvider extends AIProvider {
  const CustomProvider(super.config);

  /// Loads model ids from the OpenAI-compatible `/models` endpoint.
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
    if (data is! Map<String, dynamic> || data['data'] is! List) {
      throw const FormatException(
          'The custom provider returned an invalid /models response.');
    }

    return (data['data'] as List)
        .whereType<Map>()
        .map((model) => model['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  @override
  Future<DamageReport> analyzeImages(List<File> images,
      {String? extraContext}) async {
    // Custom endpoints are assumed OpenAI-compatible by default. If a
    // user's self-hosted server uses a different contract, they can fork
    // this class — the interface (AIProvider) stays the same everywhere
    // else in the app.
    final delegate = OpenAIProvider(config);
    try {
      return await delegate.analyzeImages(images, extraContext: extraContext);
    } catch (e) {
      // Fallback: try a minimal generic POST and surface the raw text so
      // the user can see what came back even if parsing failed.
      final dio = Dio(BaseOptions(
        baseUrl: config.baseUrl,
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          ...config.extraHeaders,
        },
      ));
      final bytes = await images.first.readAsBytes();
      final response = await dio.post('/analyze', data: {
        'model': config.model,
        'image_base64': base64Encode(bytes),
        'prompt': kDamageAnalysisPrompt,
      });

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

      return DamageReport(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        sourceMediaPath: images.first.path,
        providerLabel: label,
        modelUsed: config.model,
        items: items,
        overallConfidence: items.isEmpty
            ? 0.0
            : items.map((e) => e.confidence).reduce((a, b) => a + b) /
                items.length,
        rawModelResponse: raw,
        summary: json['summary'],
        summaryKhmer: json['summary_km'],
      );
    }
  }
}
