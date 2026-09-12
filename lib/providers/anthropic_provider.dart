import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_report.dart';
import 'ai_provider.dart';
import 'json_extractor.dart';

/// Talks to Anthropic's /v1/messages API with vision-capable Claude models.
class AnthropicProvider extends AIProvider {
  const AnthropicProvider(super.config);

  @override
  Future<DamageReport> analyzeImages(List<File> images, {String? extraContext}) async {
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

    final imageBlocks = await Future.wait(images.map((f) async {
      final bytes = await f.readAsBytes();
      final b64 = base64Encode(bytes);
      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/jpeg',
          'data': b64,
        },
      };
    }));

    final content = [
      {'type': 'text', 'text': kDamageAnalysisPrompt + (extraContext != null ? '\n\nAdditional context from user: $extraContext' : '')},
      ...imageBlocks,
    ];

    final response = await dio.post('/messages', data: {
      'model': config.model,
      'max_tokens': 2000,
      'messages': [
        {'role': 'user', 'content': content}
      ],
    });

    final textBlocks = (response.data['content'] as List<dynamic>)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');

    final json = extractJsonObject(textBlocks);

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
      rawModelResponse: textBlocks,
      summary: json['summary'],
      summaryKhmer: json['summary_km'],
    );
  }
}
