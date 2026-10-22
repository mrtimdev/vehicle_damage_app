import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';
import '../models/inspection_scope.dart';
import '../services/config_service.dart';
import '../services/history_service.dart';
import '../services/analysis_service.dart';
import '../utils/app_localizations.dart';
import '../utils/media_utils.dart';

final configServiceProvider = Provider((ref) => ConfigService());
final historyServiceProvider = Provider((ref) => HistoryService());
final analysisServiceProvider = Provider((ref) => AnalysisService());

/// Tracks active tab index in HomeScreen (0 = Analyze, 1 = History, 2 = Settings)
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Holds the active UI locale (defaults to Khmer `AppLanguage.km` and persists to Hive).
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  static const _boxName = 'app_preferences';
  static const _langKey = 'ui_language';

  AppLanguageNotifier() : super(AppLanguage.km) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      final saved = box.get(_langKey)?.toString();
      if (saved == 'en') {
        state = AppLanguage.en;
      } else if (saved == 'km') {
        state = AppLanguage.km;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await box.put(_langKey, lang.code);
    } catch (_) {}
  }

  Future<void> toggle() =>
      setLanguage(state == AppLanguage.km ? AppLanguage.en : AppLanguage.km);
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>(
  (ref) => AppLanguageNotifier(),
);

final appStringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(appLanguageProvider)),
);

/// Holds user preference for automatic component cropping (Tires, Hydraulic lines, Brakes, Engine, Exterior).
class AutoCropPartsNotifier extends StateNotifier<bool> {
  static const _boxName = 'app_preferences';
  static const _prefKey = 'enable_auto_crop_parts';

  AutoCropPartsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      final saved = box.get(_prefKey);
      if (saved is bool) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await box.put(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}

final autoCropPartsProvider =
    StateNotifierProvider<AutoCropPartsNotifier, bool>(
  (ref) => AutoCropPartsNotifier(),
);

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

final aiConfigProvider =
    StateNotifierProvider<AIConfigNotifier, AsyncValue<AIProviderConfig?>>(
  (ref) => AIConfigNotifier(ref.read(configServiceProvider)),
);

/// Holds the list of past reports, loaded from Hive with fast in-memory updates.
class HistoryNotifier extends StateNotifier<AsyncValue<List<DamageReport>>> {
  final HistoryService _service;
  HistoryNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final reports = await _service.loadAll();
      state = AsyncValue.data(reports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(DamageReport report) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = [
        report,
        ...current.where((r) => r.id != report.id),
      ];
      state = AsyncValue.data(updated);
    } else {
      await refresh();
    }
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull;
    DamageReport? target;
    if (current != null) {
      for (final r in current) {
        if (r.id == id) {
          target = r;
          break;
        }
      }
      state = AsyncValue.data(current.where((r) => r.id != id).toList());
    }
    await _service.delete(id);
    if (target != null) {
      await MediaUtils.deleteReportMedia(target.allAssociatedFilePaths);
    }
  }

  Future<void> clearAll() async {
    final current = state.valueOrNull ?? const [];
    state = const AsyncValue.data([]);
    await _service.clearAll();
    for (final r in current) {
      await MediaUtils.deleteReportMedia(r.allAssociatedFilePaths);
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<DamageReport>>>(
  (ref) => HistoryNotifier(ref.read(historyServiceProvider)),
);

/// State notifier for the active vehicle inspection scope & defect focus tags.
class InspectionScopeNotifier extends StateNotifier<InspectionScope> {
  InspectionScopeNotifier() : super(InspectionScope.initial());

  void setArea(String area) {
    state = state.copyWith(selectedArea: area);
  }

  void setSelectedArea(String area) => setArea(area);

  void toggleDefectTag(String tag) {
    final updated = Set<String>.from(state.activeDefectTags);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    state = state.copyWith(activeDefectTags: updated);
  }

  void selectAllTags() {
    state = state.copyWith(
      activeDefectTags: Set<String>.from(InspectionScope.allDefectTags),
    );
  }

  void clearAllTags() {
    state = state.copyWith(activeDefectTags: <String>{});
  }

  void reset() {
    state = InspectionScope.initial();
  }
}

final inspectionScopeProvider =
    StateNotifierProvider<InspectionScopeNotifier, InspectionScope>(
  (ref) => InspectionScopeNotifier(),
);
