import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import 'ai_provider.dart';
import 'json_extractor.dart';

/// Talks to Google's Generative Language API (Gemini) generateContent
/// endpoint with inline base64 image parts.
class GeminiProvider extends AIProvider {
  const GeminiProvider(super.config);

  @override
  Future<DamageReport> analyzeImages(List<File> images, {String? extraContext}) async {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        ...config.extraHeaders,
      },
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
    ));

    final imageParts = await Future.wait(images.map((f) async {
      final bytes = await f.readAsBytes();
      final b64 = base64Encode(bytes);
      return {
        'inline_data': {'mime_type': 'image/jpeg', 'data': b64},
      };
    }));

    final parts = [
      {'text': kDamageAnalysisPrompt + (extraContext != null ? '\n\nAdditional context from user: $extraContext' : '')},
      ...imageParts,
    ];

    final response = await dio.post(
      '/models/${config.model}:generateContent',
      queryParameters: {'key': config.apiKey},
      data: {
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 2000},
      },
    );

    final text = response.data['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = extractJsonObject(text);

    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => DamageItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final overallConfidence = items.isEmpty
        ? 1.0
        : items.map((e) => e.confidence).reduce((a, b) => a + b) / items.length;

    return DamageReport(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      sourceMediaPath: images.first.path,
      providerLabel: label,
      modelUsed: config.model,
      items: items,
      overallConfidence: overallConfidence,
      rawModelResponse: text,
      summary: json['summary'],
      summaryKhmer: json['summary_km'],
    );
  }
}
