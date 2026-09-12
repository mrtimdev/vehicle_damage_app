import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';
import '../services/config_service.dart';
import '../services/history_service.dart';
import '../services/analysis_service.dart';

final configServiceProvider = Provider((ref) => ConfigService());
final historyServiceProvider = Provider((ref) => HistoryService());
final analysisServiceProvider = Provider((ref) => AnalysisService());

/// Holds the currently active AI provider configuration, loaded from
/// secure storage on startup and updated whenever the user edits Settings.
class AIConfigNotifier extends StateNotifier<AsyncValue<AIProviderConfig?>> {
  final ConfigService _service;
  AIConfigNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _service.load();
      state = AsyncValue.data(config);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(AIProviderConfig config) async {
    await _service.save(config);
    state = AsyncValue.data(config);
  }

  Future<void> clear() async {
    await _service.clear();
    state = const AsyncValue.data(null);
  }
}

final aiConfigProvider = StateNotifierProvider<AIConfigNotifier, AsyncValue<AIProviderConfig?>>(
  (ref) => AIConfigNotifier(ref.read(configServiceProvider)),
);

/// Holds the list of past reports, loaded from Hive.
class HistoryNotifier extends StateNotifier<AsyncValue<List<DamageReport>>> {
  final HistoryService _service;
  HistoryNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final reports = await _service.loadAll();
      state = AsyncValue.data(reports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(DamageReport report) async {
    await refresh();
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    await refresh();
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<List<DamageReport>>>(
  (ref) => HistoryNotifier(ref.read(historyServiceProvider)),
);
