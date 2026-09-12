import 'package:hive_flutter/hive_flutter.dart';
import '../models/damage_report.dart';

/// Stores every completed [DamageReport] locally as JSON strings in a Hive
/// box, so users can revisit past analyses without re-uploading media.
class HistoryService {
  static const _boxName = 'damage_reports';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> save(DamageReport report) async {
    final box = await _openBox();
    await box.put(report.id, report.toJson());
  }

  Future<List<DamageReport>> loadAll() async {
    final box = await _openBox();
    final reports = box.values
        .map((e) => DamageReport.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }
}
