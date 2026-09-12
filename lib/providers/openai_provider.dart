import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import 'ai_provider.dart';
import 'json_extractor.dart';

/// Talks to OpenAI's Chat Completions API (or any OpenAI-compatible
/// endpoint if the user changes baseUrl, e.g. Azure OpenAI proxies,
/// OpenRouter, LM Studio, etc.).
class OpenAIProvider extends AIProvider {
  const OpenAIProvider(super.config);

  @override
  Future<DamageReport> analyzeImages(List<File> images, {String? extraContext}) async {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
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
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$b64'},
      };
    }));

    final userContent = [
      {'type': 'text', 'text': kDamageAnalysisPrompt + (extraContext != null ? '\n\nAdditional context from user: $extraContext' : '')},
      ...imageParts,
    ];

    final response = await dio.post('/chat/completions', data: {
      'model': config.model,
      'messages': [
        {'role': 'user', 'content': userContent}
      ],
      'temperature': 0.2,
      'max_tokens': 2000,
    });

    final content = response.data['choices'][0]['message']['content'] as String;
    final json = extractJsonObject(content);

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
      rawModelResponse: content,
      summary: json['summary'],
      summaryKhmer: json['summary_km'],
    );
  }
}
