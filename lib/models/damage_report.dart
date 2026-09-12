/// Severity levels for a detected damage item.
enum DamageSeverity { minor, moderate, severe, unknown }

extension DamageSeverityX on DamageSeverity {
  static DamageSeverity fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'minor':
        return DamageSeverity.minor;
      case 'moderate':
        return DamageSeverity.moderate;
      case 'severe':
        return DamageSeverity.severe;
      default:
        return DamageSeverity.unknown;
    }
  }

  String get label {
    switch (this) {
      case DamageSeverity.minor:
        return 'Minor';
      case DamageSeverity.moderate:
        return 'Moderate';
      case DamageSeverity.severe:
        return 'Severe';
      case DamageSeverity.unknown:
        return 'Unknown';
    }
  }
}

/// A single detected damage finding on one vehicle part.
class DamageItem {
  final String partName;
  final String partNameKhmer;
  final String damageType; // e.g. "dent", "scratch", "crack", "broken light"
  final DamageSeverity severity;

  /// Model's self-reported confidence, 0.0–1.0. This is an *estimate from
  /// the AI*, not a guarantee of correctness — always surface it to the
  /// user rather than hiding it, especially since 100% accuracy is not a
  /// realistic claim for any current vision model.
  final double confidence;

  final String? notes;

  const DamageItem({
    required this.partName,
    required this.partNameKhmer,
    required this.damageType,
    required this.severity,
    required this.confidence,
    this.notes,
  });

  /// Below this threshold we flag the item for the user to manually verify.
  bool get needsReview => confidence < 0.6;

  factory DamageItem.fromJson(Map<String, dynamic> json) {
    return DamageItem(
      partName: json['part'] ?? 'Unknown part',
      partNameKhmer: json['part_km'] ?? '',
      damageType: json['damage_type'] ?? 'unknown',
      severity: DamageSeverityX.fromString(json['severity']),
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0.0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'part': partName,
        'part_km': partNameKhmer,
        'damage_type': damageType,
        'severity': severity.name,
        'confidence': confidence,
        'notes': notes,
      };
}

/// Full analysis result for one submitted image/video frame set.
class DamageReport {
  final String id;
  final DateTime createdAt;
  final String sourceMediaPath;
  final String providerLabel;
  final String modelUsed;
  final List<DamageItem> items;

  /// Overall average confidence across all findings.
  final double overallConfidence;
  final String? rawModelResponse;
  final String? summary;
  final String? summaryKhmer;

  const DamageReport({
    required this.id,
    required this.createdAt,
    required this.sourceMediaPath,
    required this.providerLabel,
    required this.modelUsed,
    required this.items,
    required this.overallConfidence,
    this.rawModelResponse,
    this.summary,
    this.summaryKhmer,
  });

  bool get hasLowConfidenceItems => items.any((i) => i.needsReview);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'sourceMediaPath': sourceMediaPath,
        'providerLabel': providerLabel,
        'modelUsed': modelUsed,
        'items': items.map((e) => e.toJson()).toList(),
        'overallConfidence': overallConfidence,
        'rawModelResponse': rawModelResponse,
        'summary': summary,
        'summaryKhmer': summaryKhmer,
      };

  factory DamageReport.fromJson(Map<String, dynamic> json) {
    return DamageReport(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      sourceMediaPath: json['sourceMediaPath'],
      providerLabel: json['providerLabel'],
      modelUsed: json['modelUsed'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => DamageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      rawModelResponse: json['rawModelResponse'],
      summary: json['summary'],
      summaryKhmer: json['summaryKhmer'],
    );
  }
}
