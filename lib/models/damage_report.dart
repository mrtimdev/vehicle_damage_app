import 'dart:ui' show Rect;
import '../utils/app_localizations.dart';

/// Severity levels for a detected damage item.
enum DamageSeverity { minor, moderate, severe, unknown }

extension DamageSeverityX on DamageSeverity {
  static DamageSeverity fromString(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    switch (v) {
      case 'minor':
      case 'ស្រាល':
        return DamageSeverity.minor;
      case 'moderate':
      case 'មធ្យម':
        return DamageSeverity.moderate;
      case 'severe':
      case 'ធ្ងន់ធ្ងរ':
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

  String get labelKhmer => KhmerAutomotiveTranslator.severityKhmer(this);

  String get bilingualLabel => '$labelKhmer · $label';

  String localizedLabel(AppLanguage lang) =>
      lang.isKhmer ? labelKhmer : label;
}

/// Normalized 2D bounding box representing a region of interest on a vehicle image.
/// Coordinates are normalized in [0.0, 1.0] range (or parsed from 0..1000 range).
class BoundingBox {
  final double ymin;
  final double xmin;
  final double ymax;
  final double xmax;

  const BoundingBox({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
  });

  bool get isValid =>
      xmin >= 0 &&
      ymin >= 0 &&
      xmax > xmin &&
      ymax > ymin &&
      xmax <= 1.05 &&
      ymax <= 1.05;

  double get width => (xmax - xmin).clamp(0.0, 1.0);
  double get height => (ymax - ymin).clamp(0.0, 1.0);

  /// Converts normalized coords to pixel Rect given image width & height
  Rect toPixelRect(double imageWidth, double imageHeight) {
    return Rect.fromLTRB(
      (xmin * imageWidth).clamp(0.0, imageWidth),
      (ymin * imageHeight).clamp(0.0, imageHeight),
      (xmax * imageWidth).clamp(0.0, imageWidth),
      (ymax * imageHeight).clamp(0.0, imageHeight),
    );
  }

  /// Parses from dynamic list, map, or BoundingBox instance.
  /// Supports:
  /// - List of 4 numbers [ymin, xmin, ymax, xmax] (0..1000 scale or 0..1 scale)
  /// - Map with keys 'ymin', 'xmin', 'ymax', 'xmax' or 'top', 'left', 'bottom', 'right'
  static BoundingBox? fromDynamic(dynamic val) {
    if (val == null) return null;
    if (val is BoundingBox) return val;
    if (val is List && val.length >= 4) {
      final y1 = (val[0] as num?)?.toDouble() ?? 0.0;
      final x1 = (val[1] as num?)?.toDouble() ?? 0.0;
      final y2 = (val[2] as num?)?.toDouble() ?? 0.0;
      final x2 = (val[3] as num?)?.toDouble() ?? 0.0;
      final is1000Scale = y1 > 1.0 || x1 > 1.0 || y2 > 1.0 || x2 > 1.0;
      final scale = is1000Scale ? 1000.0 : 1.0;
      return BoundingBox(
        ymin: (y1 / scale).clamp(0.0, 1.0),
        xmin: (x1 / scale).clamp(0.0, 1.0),
        ymax: (y2 / scale).clamp(0.0, 1.0),
        xmax: (x2 / scale).clamp(0.0, 1.0),
      );
    }
    if (val is Map) {
      final y1 = (val['ymin'] ?? val['top'] ?? val['y'] ?? 0 as num).toDouble();
      final x1 = (val['xmin'] ?? val['left'] ?? val['x'] ?? 0 as num).toDouble();
      final y2 = (val['ymax'] ?? val['bottom'] ?? (y1 + (val['height'] ?? 0)) as num).toDouble();
      final x2 = (val['xmax'] ?? val['right'] ?? (x1 + (val['width'] ?? 0)) as num).toDouble();
      final is1000Scale = y1 > 1.0 || x1 > 1.0 || y2 > 1.0 || x2 > 1.0;
      final scale = is1000Scale ? 1000.0 : 1.0;
      return BoundingBox(
        ymin: (y1 / scale).clamp(0.0, 1.0),
        xmin: (x1 / scale).clamp(0.0, 1.0),
        ymax: (y2 / scale).clamp(0.0, 1.0),
        xmax: (x2 / scale).clamp(0.0, 1.0),
      );
    }
    return null;
  }

  List<double> toList() => [ymin, xmin, ymax, xmax];
  List<int> to1000List() => [
        (ymin * 1000).round(),
        (xmin * 1000).round(),
        (ymax * 1000).round(),
        (xmax * 1000).round(),
      ];

  Map<String, dynamic> toJson() => {
        'ymin': ymin,
        'xmin': xmin,
        'ymax': ymax,
        'xmax': xmax,
        'box_2d': to1000List(),
      };
}

/// A single detected damage finding on one vehicle part.
class DamageItem {
  final String partName;
  final String partNameKhmer;
  final String damageType; // e.g. "dent", "scratch", "crack", "broken light", "hydraulic_fault", "tire_damage"
  final String damageTypeKhmer;
  final DamageSeverity severity;

  /// Model's self-reported confidence, 0.0–1.0. This is an *estimate from
  /// the AI*, not a guarantee of correctness — always surface it to the
  /// user rather than hiding it, especially since 100% accuracy is not a
  /// realistic claim for any current vision model.
  final double confidence;

  final String? notes;
  final String? notesKhmer;

  /// Normalized bounding box of the defect/component on the vehicle image.
  final BoundingBox? boundingBox;

  /// 0-based index of the photo in [DamageReport.mediaPaths] containing this defect.
  final int imageIndex;

  /// Local cached file path of the auto-cropped component image.
  final String? croppedImagePath;

  const DamageItem({
    required this.partName,
    required this.partNameKhmer,
    required this.damageType,
    this.damageTypeKhmer = '',
    required this.severity,
    required this.confidence,
    this.notes,
    this.notesKhmer,
    this.boundingBox,
    this.imageIndex = 0,
    this.croppedImagePath,
  });

  /// Below this threshold we flag the item for the user to manually verify.
  bool get needsReview => confidence < 0.6;

  /// Indicates if this finding has an auto-crop available or a valid bounding box.
  bool get hasCrop =>
      (croppedImagePath != null && croppedImagePath!.isNotEmpty) ||
      (boundingBox != null && boundingBox!.isValid);

  /// True if this item corresponds to a tire, wheel, or rim.
  bool get isTire {
    final p = partName.toLowerCase();
    final d = damageType.toLowerCase();
    final pk = partNameKhmer;
    return p.contains('tire') ||
        p.contains('wheel') ||
        p.contains('rim') ||
        d.contains('tire') ||
        pk.contains('កង់') ||
        pk.contains('សំបកកង់');
  }

  /// True if this item corresponds to a hydraulic cylinder, line, or pump.
  bool get isHydraulic {
    final p = partName.toLowerCase();
    final d = damageType.toLowerCase();
    final pk = partNameKhmer;
    final n = (notes ?? '').toLowerCase();
    return p.contains('hydraulic') ||
        p.contains('cylinder') ||
        p.contains('hose') ||
        p.contains('pump') ||
        d.contains('hydraulic') ||
        d.contains('fluid_leak') ||
        pk.contains('អ៊ីដ្រូលីក') ||
        n.contains('hydraulic') ||
        n.contains('fluid leak');
  }

  /// True if this item corresponds to an engine bay or mechanical defect.
  bool get isMechanicalEngine {
    final p = partName.toLowerCase();
    final d = damageType.toLowerCase();
    return p.contains('engine') ||
        p.contains('belt') ||
        p.contains('valve') ||
        p.contains('piston') ||
        d.contains('engine') ||
        d.contains('mechanical');
  }

  /// True if this item corresponds to a brake component.
  bool get isBrake {
    final p = partName.toLowerCase();
    final d = damageType.toLowerCase();
    return p.contains('brake') ||
        p.contains('rotor') ||
        p.contains('caliper') ||
        d.contains('brake');
  }

  /// Categorical label for UI component grouping.
  String componentCategory({required bool isKhmer}) {
    if (isTire) return isKhmer ? 'កង់ និងសំបកកង់' : 'Tire & Wheel';
    if (isHydraulic) return isKhmer ? 'ប្រព័ន្ធអ៊ីដ្រូលីក' : 'Hydraulic System';
    if (isMechanicalEngine) {
      return isKhmer ? 'ម៉ាស៊ីន និងមេកានិច' : 'Engine & Mechanical';
    }
    if (isBrake) return isKhmer ? 'ប្រព័ន្ធហ្វ្រាំង' : 'Braking System';
    return isKhmer ? 'តួ និងផ្នែកខាងក្រៅ' : 'Exterior & Body';
  }

  /// Human-readable formatted English defect category label.
  String get formattedDamageType {
    final cleaned = damageType.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Unspecified Defect';
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Resolved Khmer label for this vehicle part (uses sanitized `part_km` if
  /// present, or translates common English part names into pure Khmer).
  String get resolvedPartNameKhmer => KhmerAutomotiveTranslator.partNameKhmer(
        partName,
        aiProvidedKhmer: partNameKhmer,
      );

  /// Resolved Khmer label for this defect type (uses AI's `damage_type_km` if
  /// present, or translates canonical `damageType` into Khmer).
  String get resolvedDamageTypeKhmer =>
      KhmerAutomotiveTranslator.damageTypeKhmer(
        damageType,
        aiProvidedKhmer: damageTypeKhmer,
      );

  /// Bilingual defect category label, e.g. `ច្រេះ និងពុកផុយ (Rust)`.
  String localizedDamageType(AppLanguage lang) =>
      KhmerAutomotiveTranslator.damageTypeDisplay(this, lang: lang);

  /// Resolved Khmer description for this finding (uses AI's `notes_km` if
  /// present, or synthesizes an accurate Khmer diagnostic description).
  String get resolvedNotesKhmer =>
      KhmerAutomotiveTranslator.resolveNotesKhmer(this);

  DamageItem copyWith({
    String? partName,
    String? partNameKhmer,
    String? damageType,
    String? damageTypeKhmer,
    DamageSeverity? severity,
    double? confidence,
    String? notes,
    String? notesKhmer,
    BoundingBox? boundingBox,
    int? imageIndex,
    String? croppedImagePath,
  }) {
    return DamageItem(
      partName: partName ?? this.partName,
      partNameKhmer: partNameKhmer ?? this.partNameKhmer,
      damageType: damageType ?? this.damageType,
      damageTypeKhmer: damageTypeKhmer ?? this.damageTypeKhmer,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
      notesKhmer: notesKhmer ?? this.notesKhmer,
      boundingBox: boundingBox ?? this.boundingBox,
      imageIndex: imageIndex ?? this.imageIndex,
      croppedImagePath: croppedImagePath ?? this.croppedImagePath,
    );
  }

  factory DamageItem.fromJson(Map<String, dynamic> json) {
    final rawNotesKm = KhmerAutomotiveTranslator.sanitizeKhmer(
      json['notes_km']?.toString(),
    );
    return DamageItem(
      partName: json['part']?.toString() ?? 'Unknown part',
      partNameKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['part_km']?.toString(),
      ),
      damageType: json['damage_type']?.toString() ?? 'unknown',
      damageTypeKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['damage_type_km']?.toString(),
      ),
      severity: DamageSeverityX.fromString(
        json['severity']?.toString() ?? json['severity_km']?.toString(),
      ),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble().clamp(0.0, 1.0)
          : 0.0,
      notes: json['notes']?.toString(),
      notesKhmer: rawNotesKm.isEmpty ? null : rawNotesKm,
      boundingBox: BoundingBox.fromDynamic(
        json['bounding_box'] ?? json['box_2d'] ?? json['box'],
      ),
      imageIndex: (json['image_index'] is num)
          ? (json['image_index'] as num).toInt()
          : 0,
      croppedImagePath: json['cropped_image_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'part': partName,
        'part_km': partNameKhmer,
        'damage_type': damageType,
        'damage_type_km': damageTypeKhmer,
        'severity': severity.name,
        'severity_km': severity.labelKhmer,
        'confidence': confidence,
        'notes': notes,
        'notes_km': notesKhmer,
        if (boundingBox != null) 'box_2d': boundingBox!.to1000List(),
        if (boundingBox != null) 'bounding_box': boundingBox!.toList(),
        'image_index': imageIndex,
        if (croppedImagePath != null) 'cropped_image_path': croppedImagePath,
      };
}

/// Detected vehicle specification and registration attributes.
class VehicleIdentity {
  final String? make;
  final String? model;
  final String? yearRange;
  final String? bodyType;
  final String? bodyTypeKhmer;
  final String? color;
  final String? colorKhmer;
  final String? licensePlate;
  final String? vin;
  final int? odometerReading;

  const VehicleIdentity({
    this.make,
    this.model,
    this.yearRange,
    this.bodyType,
    this.bodyTypeKhmer,
    this.color,
    this.colorKhmer,
    this.licensePlate,
    this.vin,
    this.odometerReading,
  });

  bool get isEmpty =>
      (make == null || make!.isEmpty) &&
      (model == null || model!.isEmpty) &&
      (licensePlate == null || licensePlate!.isEmpty) &&
      (vin == null || vin!.isEmpty);

  String get displayName {
    final parts = [make, model, yearRange].where((s) => s != null && s.isNotEmpty);
    if (parts.isEmpty) return 'Vehicle (Unidentified)';
    return parts.join(' ');
  }

  factory VehicleIdentity.fromJson(Map<String, dynamic> json) {
    return VehicleIdentity(
      make: json['make']?.toString(),
      model: json['model']?.toString(),
      yearRange: json['year_range']?.toString() ?? json['year']?.toString(),
      bodyType: json['body_type']?.toString(),
      bodyTypeKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['body_type_km']?.toString(),
      ),
      color: json['color']?.toString(),
      colorKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['color_km']?.toString(),
      ),
      licensePlate: json['license_plate']?.toString(),
      vin: json['vin']?.toString(),
      odometerReading: json['odometer_reading'] is num
          ? (json['odometer_reading'] as num).toInt()
          : int.tryParse(json['odometer_reading']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'year_range': yearRange,
        'body_type': bodyType,
        'body_type_km': bodyTypeKhmer,
        'color': color,
        'color_km': colorKhmer,
        'license_plate': licensePlate,
        'vin': vin,
        'odometer_reading': odometerReading,
      };
}

/// Overall vehicle health score and roadworthiness assessment.
class VehicleHealthAssessment {
  final int conditionScore; // 0 to 100
  final String conditionGrade; // e.g. A, B, C, D, F
  final String roadworthiness; // e.g. Roadworthy, Needs Attention, Unsafe
  final String? roadworthinessKhmer;
  final String? repairCostTier; // Minor, Moderate, Major
  final String? repairCostTierKhmer;

  const VehicleHealthAssessment({
    required this.conditionScore,
    required this.conditionGrade,
    required this.roadworthiness,
    this.roadworthinessKhmer,
    this.repairCostTier,
    this.repairCostTierKhmer,
  });

  bool get isRoadworthy =>
      roadworthiness.toLowerCase().contains('roadworthy') &&
      !roadworthiness.toLowerCase().contains('not') &&
      !roadworthiness.toLowerCase().contains('un');

  factory VehicleHealthAssessment.fromJson(Map<String, dynamic> json) {
    return VehicleHealthAssessment(
      conditionScore: (json['condition_score'] is num)
          ? (json['condition_score'] as num).toInt().clamp(0, 100)
          : 80,
      conditionGrade: json['condition_grade']?.toString() ?? 'B',
      roadworthiness: json['roadworthiness']?.toString() ?? 'Roadworthy',
      roadworthinessKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['roadworthiness_km']?.toString(),
      ),
      repairCostTier: json['repair_cost_tier']?.toString(),
      repairCostTierKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['repair_cost_tier_km']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'condition_score': conditionScore,
        'condition_grade': conditionGrade,
        'roadworthiness': roadworthiness,
        'roadworthiness_km': roadworthinessKhmer,
        'repair_cost_tier': repairCostTier,
        'repair_cost_tier_km': repairCostTierKhmer,
      };
}

/// Detected mechanical acoustic anomaly from audio in video.
class AcousticAnomaly {
  final String anomalyType;
  final String anomalyTypeKhmer;
  final double timestampSeconds;
  final DamageSeverity severity;
  final double confidence;
  final String diagnosticAdvice;
  final String diagnosticAdviceKhmer;

  const AcousticAnomaly({
    required this.anomalyType,
    required this.anomalyTypeKhmer,
    required this.timestampSeconds,
    required this.severity,
    required this.confidence,
    required this.diagnosticAdvice,
    required this.diagnosticAdviceKhmer,
  });

  factory AcousticAnomaly.fromJson(Map<String, dynamic> json) {
    return AcousticAnomaly(
      anomalyType: json['anomaly_type']?.toString() ?? 'unknown_sound',
      anomalyTypeKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['anomaly_type_km']?.toString(),
      ),
      timestampSeconds: (json['timestamp_seconds'] is num)
          ? (json['timestamp_seconds'] as num).toDouble()
          : 0.0,
      severity: DamageSeverityX.fromString(
        json['severity']?.toString() ?? json['severity_km']?.toString(),
      ),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble().clamp(0.0, 1.0)
          : 0.0,
      diagnosticAdvice: json['diagnostic_advice']?.toString() ?? '',
      diagnosticAdviceKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['diagnostic_advice_km']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'anomaly_type': anomalyType,
        'anomaly_type_km': anomalyTypeKhmer,
        'timestamp_seconds': timestampSeconds,
        'severity': severity.name,
        'severity_km': severity.labelKhmer,
        'confidence': confidence,
        'diagnostic_advice': diagnosticAdvice,
        'diagnostic_advice_km': diagnosticAdviceKhmer,
      };
}

/// Analysis result of vehicle mechanical audio extracted from video or URL.
class AcousticAnalysisResult {
  final bool audioTrackDetected;
  final int acousticHealthScore; // 0 to 100
  final String engineSoundProfile;
  final String engineSoundProfileKhmer;
  final List<AcousticAnomaly> anomalies;
  final String? audioSummary;
  final String? audioSummaryKhmer;

  const AcousticAnalysisResult({
    required this.audioTrackDetected,
    required this.acousticHealthScore,
    required this.engineSoundProfile,
    required this.engineSoundProfileKhmer,
    required this.anomalies,
    this.audioSummary,
    this.audioSummaryKhmer,
  });

  factory AcousticAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AcousticAnalysisResult(
      audioTrackDetected: json['audio_track_detected'] == true ||
          json['audio_track_detected'] == 'true',
      acousticHealthScore: (json['acoustic_health_score'] is num)
          ? (json['acoustic_health_score'] as num).toInt().clamp(0, 100)
          : 85,
      engineSoundProfile:
          json['engine_sound_profile']?.toString() ?? 'Normal Operation',
      engineSoundProfileKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['engine_sound_profile_km']?.toString(),
      ),
      anomalies: (json['anomalies'] as List<dynamic>? ?? [])
          .map((e) =>
              AcousticAnomaly.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      audioSummary: json['audio_summary']?.toString(),
      audioSummaryKhmer: KhmerAutomotiveTranslator.sanitizeKhmer(
        json['audio_summary_km']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'audio_track_detected': audioTrackDetected,
        'acoustic_health_score': acousticHealthScore,
        'engine_sound_profile': engineSoundProfile,
        'engine_sound_profile_km': engineSoundProfileKhmer,
        'anomalies': anomalies.map((e) => e.toJson()).toList(),
        'audio_summary': audioSummary,
        'audio_summary_km': audioSummaryKhmer,
      };
}

/// Full analysis result for one submitted image/video frame set.
class DamageReport {
  final String id;
  final DateTime createdAt;
  final String sourceMediaPath;
  final List<String> mediaPaths;
  final String providerLabel;
  final String modelUsed;
  final List<DamageItem> items;

  /// Overall average confidence across all findings.
  final double overallConfidence;
  final String? rawModelResponse;
  final String? summary;
  final String? summaryKhmer;

  /// Optional vehicle specification & registration identity
  final VehicleIdentity? vehicleIdentity;

  /// Optional overall condition scoring & roadworthiness
  final VehicleHealthAssessment? healthAssessment;

  /// Optional mechanical sound analysis extracted from video
  final AcousticAnalysisResult? acousticAnalysis;

  /// Path to persisted video if the inspection source was a video file or video URL.
  final String? videoPath;

  /// Path to persisted audio track if extracted or recorded.
  final String? audioPath;

  const DamageReport({
    required this.id,
    required this.createdAt,
    required this.sourceMediaPath,
    this.mediaPaths = const [],
    required this.providerLabel,
    required this.modelUsed,
    required this.items,
    required this.overallConfidence,
    this.rawModelResponse,
    this.summary,
    this.summaryKhmer,
    this.vehicleIdentity,
    this.healthAssessment,
    this.acousticAnalysis,
    this.videoPath,
    this.audioPath,
  });

  List<String> get allMediaPaths {
    if (mediaPaths.isNotEmpty) return mediaPaths;
    if (sourceMediaPath.isNotEmpty &&
        sourceMediaPath != videoPath &&
        sourceMediaPath != audioPath) {
      return [sourceMediaPath];
    }
    return const [];
  }

  /// All persisted file paths associated with this report, including photos,
  /// original inspection video, and extracted audio.
  List<String> get allAssociatedFilePaths {
    final paths = <String>[];
    paths.addAll(mediaPaths);
    if (sourceMediaPath.isNotEmpty && !paths.contains(sourceMediaPath)) {
      paths.add(sourceMediaPath);
    }
    if (videoPath != null &&
        videoPath!.isNotEmpty &&
        !paths.contains(videoPath)) {
      paths.add(videoPath!);
    }
    if (audioPath != null &&
        audioPath!.isNotEmpty &&
        !paths.contains(audioPath)) {
      paths.add(audioPath!);
    }
    return paths;
  }

  /// Resolved Khmer summary (uses sanitized `summaryKhmer` or synthesizes a
  /// pure Khmer overview if missing).
  String get resolvedSummaryKhmer =>
      KhmerAutomotiveTranslator.resolveSummaryKhmer(this);

  bool get hasLowConfidenceItems => items.any((i) => i.needsReview);
  bool get hasAcousticAnomalies =>
      acousticAnalysis?.anomalies.isNotEmpty == true;
  int get severeCount =>
      items.where((i) => i.severity == DamageSeverity.severe).length;
  int get moderateCount =>
      items.where((i) => i.severity == DamageSeverity.moderate).length;
  int get minorCount =>
      items.where((i) => i.severity == DamageSeverity.minor).length;

  DamageReport copyWith({
    String? sourceMediaPath,
    List<String>? mediaPaths,
    List<DamageItem>? items,
    VehicleIdentity? vehicleIdentity,
    VehicleHealthAssessment? healthAssessment,
    AcousticAnalysisResult? acousticAnalysis,
    String? videoPath,
    String? audioPath,
  }) {
    return DamageReport(
      id: id,
      createdAt: createdAt,
      sourceMediaPath: sourceMediaPath ?? this.sourceMediaPath,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      providerLabel: providerLabel,
      modelUsed: modelUsed,
      items: items ?? this.items,
      overallConfidence: overallConfidence,
      rawModelResponse: rawModelResponse,
      summary: summary,
      summaryKhmer: summaryKhmer,
      vehicleIdentity: vehicleIdentity ?? this.vehicleIdentity,
      healthAssessment: healthAssessment ?? this.healthAssessment,
      acousticAnalysis: acousticAnalysis ?? this.acousticAnalysis,
      videoPath: videoPath ?? this.videoPath,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'sourceMediaPath': sourceMediaPath,
        'mediaPaths': allMediaPaths,
        'providerLabel': providerLabel,
        'modelUsed': modelUsed,
        'items': items.map((e) => e.toJson()).toList(),
        'overallConfidence': overallConfidence,
        'rawModelResponse': rawModelResponse,
        'summary': summary,
        'summaryKhmer': summaryKhmer,
        if (vehicleIdentity != null) 'vehicleIdentity': vehicleIdentity!.toJson(),
        if (healthAssessment != null)
          'healthAssessment': healthAssessment!.toJson(),
        if (acousticAnalysis != null)
          'acousticAnalysis': acousticAnalysis!.toJson(),
        if (videoPath != null) 'videoPath': videoPath,
        if (audioPath != null) 'audioPath': audioPath,
      };

  factory DamageReport.fromJson(Map<String, dynamic> json) {
    final primaryPath = json['sourceMediaPath']?.toString() ?? '';
    final rawPaths = (json['mediaPaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((p) => p.isNotEmpty)
            .toList() ??
        (primaryPath.isNotEmpty ? [primaryPath] : <String>[]);
    final rawSumKm = KhmerAutomotiveTranslator.sanitizeKhmer(
      json['summaryKhmer']?.toString() ?? json['summary_km']?.toString(),
    );

    VehicleIdentity? parsedIdentity;
    if (json['vehicleIdentity'] is Map) {
      parsedIdentity = VehicleIdentity.fromJson(
        Map<String, dynamic>.from(json['vehicleIdentity'] as Map),
      );
    } else if (json['vehicle_identity'] is Map) {
      parsedIdentity = VehicleIdentity.fromJson(
        Map<String, dynamic>.from(json['vehicle_identity'] as Map),
      );
    }

    VehicleHealthAssessment? parsedHealth;
    if (json['healthAssessment'] is Map) {
      parsedHealth = VehicleHealthAssessment.fromJson(
        Map<String, dynamic>.from(json['healthAssessment'] as Map),
      );
    } else if (json['health_assessment'] is Map) {
      parsedHealth = VehicleHealthAssessment.fromJson(
        Map<String, dynamic>.from(json['health_assessment'] as Map),
      );
    }

    AcousticAnalysisResult? parsedAcoustic;
    if (json['acousticAnalysis'] is Map) {
      parsedAcoustic = AcousticAnalysisResult.fromJson(
        Map<String, dynamic>.from(json['acousticAnalysis'] as Map),
      );
    } else if (json['acoustic_analysis'] is Map) {
      parsedAcoustic = AcousticAnalysisResult.fromJson(
        Map<String, dynamic>.from(json['acoustic_analysis'] as Map),
      );
    }

    final videoPath =
        json['videoPath']?.toString() ?? json['video_path']?.toString();
    final audioPath =
        json['audioPath']?.toString() ?? json['audio_path']?.toString();

    return DamageReport(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      sourceMediaPath: primaryPath.isNotEmpty
          ? primaryPath
          : (rawPaths.isNotEmpty ? rawPaths.first : ''),
      mediaPaths: rawPaths,
      providerLabel: json['providerLabel']?.toString() ?? 'AI Provider',
      modelUsed: json['modelUsed']?.toString() ?? 'unknown',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => DamageItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      overallConfidence:
          (json['overallConfidence'] as num?)?.toDouble().clamp(0.0, 1.0) ??
              0.0,
      rawModelResponse: json['rawModelResponse']?.toString(),
      summary: json['summary']?.toString(),
      summaryKhmer: rawSumKm.isEmpty ? null : rawSumKm,
      vehicleIdentity: parsedIdentity,
      healthAssessment: parsedHealth,
      acousticAnalysis: parsedAcoustic,
      videoPath: (videoPath?.isNotEmpty == true) ? videoPath : null,
      audioPath: (audioPath?.isNotEmpty == true) ? audioPath : null,
    );
  }
}
