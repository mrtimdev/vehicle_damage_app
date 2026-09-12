import 'dart:io';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';
import '../providers/provider_factory.dart';
import 'history_service.dart';

/// Exception thrown when analysis is requested but no valid AI provider
/// has been configured yet.
class ProviderNotConfiguredException implements Exception {
  final String message;
  ProviderNotConfiguredException([this.message = 'No AI provider configured. Please set one up in Settings.']);
  @override
  String toString() => message;
}

/// High-level entry point the UI calls: given a config and some media
/// files, runs the analysis through the right provider adapter and saves
/// the result to local history.
class AnalysisService {
  final HistoryService _historyService = HistoryService();

  Future<DamageReport> analyze({
    required AIProviderConfig? config,
    required List<File> images,
    String? extraContext,
  }) async {
    if (config == null || !config.isValid) {
      throw ProviderNotConfiguredException();
    }
    final provider = AIProviderFactory.build(config);
    final report = await provider.analyzeImages(images, extraContext: extraContext);
    await _historyService.save(report);
    return report;
  }
}
